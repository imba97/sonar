import { common } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import { fileIo, fileUri, WriteOptions } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { Song } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';

export interface MediaCommandCallbacks {
  onPlay?: () => Promise<void>;
  onPause?: () => Promise<void>;
  onNext?: () => Promise<void>;
  onPrevious?: () => Promise<void>;
  onSeek?: (positionMs: number) => Promise<void>;
}

const SESSION_TAG: string = 'sonar_audio_session';
const COVER_CACHE_PREFIX: string = 'sonar_cover_';
const COVER_CACHE_EXT: string = '.img';
const COVER_SIZE: number = 320;
const MAX_COVER_CACHE_COUNT: number = 100;
const PLAYBACK_STATE_SYNC_INTERVAL_MS: number = 1200;
const METADATA_RETRY_DELAY_MS: number = 500;
const METADATA_RETRY_ATTEMPTS: number = 2;

export class SystemMediaSession {
  private static context: common.UIAbilityContext | null = null;
  private static session: avSession.AVSession | null = null;
  private static callbacks: MediaCommandCallbacks = {};
  private static eventsRegistered: boolean = false;
  private static coverUriCache: Map<string, string> = new Map<string, string>();
  private static inFlightCoverTasks: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private static coverRefreshChecked: Set<string> = new Set<string>();
  private static currentAssetId: string = '';
  private static lastPlaybackStateSyncAt: number = 0;
  private static lastPlaybackStateIsPlaying: boolean = false;
  private static lastPlaybackSyncSecond: number = -1;

  static setContext(context: common.UIAbilityContext): void {
    SystemMediaSession.context = context;
  }

  static setCallbacks(callbacks: MediaCommandCallbacks): void {
    SystemMediaSession.callbacks = callbacks;
  }

  static async syncSong(song: Song | null, positionMs: number, durationMs: number, isPlaying: boolean): Promise<void> {
    const session: avSession.AVSession | null = await SystemMediaSession.ensureSession();
    if (session === null) {
      return;
    }
    if (song !== null) {
      SystemMediaSession.currentAssetId = song.id;
      const coverUrl: string = SystemMediaSession.resolveBestEffortCoverMediaImage(song);
      const metadata: avSession.AVMetadata =
        SystemMediaSession.buildMetadata(song, durationMs > 0 ? durationMs : song.duration * 1000, coverUrl);
      await SystemMediaSession.setMetadataWithRetry(session, metadata, song.id, 1);
      void SystemMediaSession.refreshCoverAsync(song, durationMs);
    } else {
      SystemMediaSession.currentAssetId = '';
    }
    await SystemMediaSession.syncPlaybackState(positionMs, isPlaying);
  }

  static async syncPlaybackState(positionMs: number, isPlaying: boolean, force: boolean = false): Promise<void> {
    const session: avSession.AVSession | null = await SystemMediaSession.ensureSession();
    if (session === null) {
      return;
    }
    const now: number = Date.now();
    const currentSecond: number = Math.floor(positionMs / 1000);
    if (!force && isPlaying && currentSecond === SystemMediaSession.lastPlaybackSyncSecond) {
      return;
    }
    if (!force && isPlaying === SystemMediaSession.lastPlaybackStateIsPlaying &&
      now - SystemMediaSession.lastPlaybackStateSyncAt < PLAYBACK_STATE_SYNC_INTERVAL_MS) {
      return;
    }
    const playbackState: avSession.AVPlaybackState = {
      state: isPlaying
        ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
        : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: 1.0,
      position: {
        elapsedTime: positionMs,
        updateTime: Date.now()
      }
    };
    try {
      await session.setAVPlaybackState(playbackState);
      SystemMediaSession.lastPlaybackStateSyncAt = now;
      SystemMediaSession.lastPlaybackStateIsPlaying = isPlaying;
      SystemMediaSession.lastPlaybackSyncSecond = currentSecond;
    } catch (err) {
      Logger.warn('SystemMediaSession', `setAVPlaybackState failed: ${(err as Error).message}`);
    }
  }

  static async release(): Promise<void> {
    if (SystemMediaSession.session === null) {
      return;
    }
    try {
      await SystemMediaSession.session.deactivate();
    } catch (err) {
      Logger.warn('SystemMediaSession', `deactivate failed: ${(err as Error).message}`);
    }
    SystemMediaSession.session = null;
    SystemMediaSession.eventsRegistered = false;
    SystemMediaSession.lastPlaybackSyncSecond = -1;
  }

  private static async ensureSession(): Promise<avSession.AVSession | null> {
    if (SystemMediaSession.session !== null) {
      return SystemMediaSession.session;
    }
    if (SystemMediaSession.context === null) {
      return null;
    }
    try {
      SystemMediaSession.session = await avSession.createAVSession(SystemMediaSession.context, SESSION_TAG, 'audio');
      await SystemMediaSession.session.activate();
      SystemMediaSession.registerEvents();
      return SystemMediaSession.session;
    } catch (err) {
      Logger.warn('SystemMediaSession', `createAVSession failed: ${(err as Error).message}`);
      return null;
    }
  }

  private static registerEvents(): void {
    if (SystemMediaSession.session === null || SystemMediaSession.eventsRegistered) {
      return;
    }
    try {
      SystemMediaSession.session.on('play', () => {
        const callback: (() => Promise<void>) | undefined = SystemMediaSession.callbacks.onPlay;
        if (callback !== undefined) {
          void callback();
        }
      });
      SystemMediaSession.session.on('pause', () => {
        const callback: (() => Promise<void>) | undefined = SystemMediaSession.callbacks.onPause;
        if (callback !== undefined) {
          void callback();
        }
      });
      SystemMediaSession.session.on('playNext', () => {
        const callback: (() => Promise<void>) | undefined = SystemMediaSession.callbacks.onNext;
        if (callback !== undefined) {
          void callback();
        }
      });
      SystemMediaSession.session.on('playPrevious', () => {
        const callback: (() => Promise<void>) | undefined = SystemMediaSession.callbacks.onPrevious;
        if (callback !== undefined) {
          void callback();
        }
      });
      SystemMediaSession.session.on('seek', (timeMs: number) => {
        const callback: ((positionMs: number) => Promise<void>) | undefined = SystemMediaSession.callbacks.onSeek;
        if (callback !== undefined) {
          void callback(timeMs);
        }
      });
    } catch (err) {
      Logger.warn('SystemMediaSession', `register command listeners failed: ${(err as Error).message}`);
      return;
    }
    SystemMediaSession.eventsRegistered = true;
  }

  private static resolveCoverUrl(song: Song): string {
    if (song.coverArt === undefined || song.coverArt.length === 0) {
      return '';
    }
    try {
      return SubsonicClient.getInstance().getCoverArtUrl(song.coverArt, COVER_SIZE);
    } catch (err) {
      Logger.warn('SystemMediaSession', `resolve cover url failed: ${(err as Error).message}`);
      return '';
    }
  }

  private static resolveBestEffortCoverMediaImage(song: Song): string {
    if (song.coverArt === undefined || song.coverArt.length === 0) {
      return '';
    }
    const coverArtId: string = song.coverArt;
    const cachedUri: string | undefined = SystemMediaSession.coverUriCache.get(coverArtId);
    if (cachedUri !== undefined && cachedUri.length > 0 && SystemMediaSession.isCachedUriValid(coverArtId, cachedUri)) {
      SystemMediaSession.touchCoverCache(coverArtId, cachedUri);
      return cachedUri;
    }
    const localPath: string = SystemMediaSession.buildCoverCachePathById(coverArtId);
    if (SystemMediaSession.isFilePathValid(localPath)) {
      const localUri: string = SystemMediaSession.safePathToUri(localPath);
      if (localUri.length > 0) {
        SystemMediaSession.touchCoverCache(coverArtId, localUri);
        return localUri;
      }
    }
    return SystemMediaSession.resolveCoverUrl(song);
  }

  private static async refreshCoverAsync(song: Song, durationMs: number): Promise<void> {
    if (song.coverArt === undefined || song.coverArt.length === 0) {
      return;
    }
    const coverArtId: string = song.coverArt;
    const coverUri: string = await SystemMediaSession.resolveCoverMediaImageWithCache(song);
    if (coverUri.length === 0) {
      return;
    }
    const session: avSession.AVSession | null = SystemMediaSession.session;
    if (session === null || SystemMediaSession.currentAssetId !== song.id) {
      return;
    }
    const metadata: avSession.AVMetadata =
      SystemMediaSession.buildMetadata(song, durationMs > 0 ? durationMs : song.duration * 1000, coverUri);
    const metadataOk: boolean =
      await SystemMediaSession.setMetadataWithRetry(session, metadata, song.id, METADATA_RETRY_ATTEMPTS);
    if (!metadataOk) {
      const remoteCover: string = SystemMediaSession.resolveCoverUrl(song);
      if (remoteCover.length > 0 && remoteCover !== coverUri && SystemMediaSession.currentAssetId === song.id) {
        const remoteMetadata: avSession.AVMetadata =
          SystemMediaSession.buildMetadata(song, durationMs > 0 ? durationMs : song.duration * 1000, remoteCover);
        await SystemMediaSession.setMetadataWithRetry(session, remoteMetadata, song.id, 1);
      }
    }
  }

  private static async resolveCoverMediaImageWithCache(song: Song): Promise<string> {
    if (song.coverArt === undefined || song.coverArt.length === 0) {
      return '';
    }
    const coverArtId: string = song.coverArt;
    const cachedUri: string | undefined = SystemMediaSession.coverUriCache.get(coverArtId);
    if (cachedUri !== undefined && cachedUri.length > 0 && SystemMediaSession.isCachedUriValid(coverArtId, cachedUri)) {
      SystemMediaSession.touchCoverCache(coverArtId, cachedUri);
      return cachedUri;
    }
    if (cachedUri !== undefined) {
      SystemMediaSession.coverUriCache.delete(coverArtId);
    }
    const localPath: string = SystemMediaSession.buildCoverCachePathById(coverArtId);
    if (SystemMediaSession.isFilePathValid(localPath)) {
      const localUri: string = SystemMediaSession.safePathToUri(localPath);
      if (localUri.length > 0) {
        SystemMediaSession.touchCoverCache(coverArtId, localUri);
        if (!SystemMediaSession.coverRefreshChecked.has(coverArtId)) {
          const refreshed: string = await SystemMediaSession.runSingleFlightCoverDownload(song, localPath, coverArtId);
          SystemMediaSession.coverRefreshChecked.add(coverArtId);
          if (refreshed.length > 0) {
            return refreshed;
          }
        }
        return localUri;
      }
    }
    const downloaded: string = await SystemMediaSession.runSingleFlightCoverDownload(song, localPath, coverArtId);
    SystemMediaSession.coverRefreshChecked.add(coverArtId);
    return downloaded;
  }

  private static async downloadAndCacheCover(song: Song, localPath: string): Promise<string> {
    const remoteUrl: string = SystemMediaSession.resolveCoverUrl(song);
    if (remoteUrl.length === 0) {
      return '';
    }
    try {
      await SystemMediaSession.downloadCoverToLocal(remoteUrl, localPath);
      const localUri: string = SystemMediaSession.safePathToUri(localPath);
      if (localUri.length === 0) {
        return remoteUrl;
      }
      if (song.coverArt !== undefined) {
        SystemMediaSession.touchCoverCache(song.coverArt, localUri);
      }
      SystemMediaSession.compactCoverCacheIfNeeded();
      return localUri;
    } catch (err) {
      Logger.warn('SystemMediaSession', `cache cover failed, fallback remote: ${(err as Error).message}`);
      return remoteUrl;
    }
  }

  private static async runSingleFlightCoverDownload(song: Song, localPath: string, coverArtId: string): Promise<string> {
    const inFlight: Promise<string> | undefined = SystemMediaSession.inFlightCoverTasks.get(coverArtId);
    if (inFlight !== undefined) {
      return await inFlight;
    }
    const task: Promise<string> = SystemMediaSession.downloadAndCacheCover(song, localPath);
    SystemMediaSession.inFlightCoverTasks.set(coverArtId, task);
    try {
      return await task;
    } finally {
      SystemMediaSession.inFlightCoverTasks.delete(coverArtId);
    }
  }

  private static buildCoverCachePathById(coverArtId: string): string {
    const context: common.UIAbilityContext | null = SystemMediaSession.context;
    if (context === null) {
      return '';
    }
    const safeId: string = coverArtId.replace(/[^a-zA-Z0-9_-]/g, '_');
    return `${context.cacheDir}/${COVER_CACHE_PREFIX}${safeId}${COVER_CACHE_EXT}`;
  }

  private static async downloadCoverToLocal(remoteUrl: string, localPath: string): Promise<void> {
    if (localPath.length === 0) {
      throw new Error('invalid local cache path');
    }
    const request = http.createHttp();
    try {
      const response = await (async () => {
        try {
          return await request.request(remoteUrl, {
            method: http.RequestMethod.GET,
            expectDataType: http.HttpDataType.ARRAY_BUFFER,
            connectTimeout: 8000,
            readTimeout: 10000
          });
        } catch (err) {
          throw new Error(`request cover failed: ${(err as Error).message}`);
        }
      })();
      if (response.responseCode !== http.ResponseCode.OK) {
        throw new Error(`http status ${response.responseCode}`);
      }
      const content: ArrayBuffer = response.result as ArrayBuffer;
      try {
        fileIo.unlinkSync(localPath);
      } catch (_err) {
      }
      try {
        const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        try {
          const writeOptions: WriteOptions = {
            offset: 0,
            length: content.byteLength
          };
          try {
            fileIo.writeSync(file.fd, content, writeOptions);
          } catch (err) {
            throw new Error(`write cover file failed: ${(err as Error).message}`);
          }
        } finally {
          try {
            fileIo.closeSync(file);
          } catch (err) {
            Logger.warn('SystemMediaSession', `close cover file failed: ${(err as Error).message}`);
          }
        }
      } catch (err) {
        throw new Error(`open cover file failed: ${(err as Error).message}`);
      }
    } finally {
      request.destroy();
    }
  }

  private static touchCoverCache(coverArtId: string, uri: string): void {
    if (SystemMediaSession.coverUriCache.has(coverArtId)) {
      SystemMediaSession.coverUriCache.delete(coverArtId);
    }
    SystemMediaSession.coverUriCache.set(coverArtId, uri);
  }

  private static safePathToUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(path);
    } catch (_err) {
      return '';
    }
  }

  private static isCachedUriValid(coverArtId: string, uri: string): boolean {
    if (uri.length === 0) {
      return false;
    }
    const expectedPath: string = SystemMediaSession.buildCoverCachePathById(coverArtId);
    return SystemMediaSession.isFilePathValid(expectedPath);
  }

  private static isFilePathValid(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      fileIo.statSync(path);
      return true;
    } catch (_err) {
      return false;
    }
  }

  private static compactCoverCacheIfNeeded(): void {
    while (SystemMediaSession.coverUriCache.size > MAX_COVER_CACHE_COUNT) {
      const oldestEntry: IterableIterator<[string, string]> = SystemMediaSession.coverUriCache.entries();
      const first: IteratorResult<[string, string]> = oldestEntry.next();
      if (first.done) {
        return;
      }
      const oldestCoverId: string = first.value[0];
      const filePath: string = SystemMediaSession.buildCoverCachePathById(oldestCoverId);
      SystemMediaSession.coverUriCache.delete(oldestCoverId);
      if (filePath.length > 0) {
        try {
          fileIo.unlinkSync(filePath);
        } catch (_err) {
        }
      }
    }
  }

  private static buildMetadata(song: Song, durationMs: number, mediaImage: string): avSession.AVMetadata {
    if (mediaImage.length > 0) {
      return {
        assetId: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        mediaImage,
        duration: durationMs
      };
    }
    return {
      assetId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: durationMs
    };
  }

  private static async setMetadataWithRetry(session: avSession.AVSession, metadata: avSession.AVMetadata,
    expectedAssetId: string, attempts: number): Promise<boolean> {
    const maxAttempts: number = attempts > 0 ? attempts : 1;
    for (let i: number = 0; i < maxAttempts; i++) {
      if (SystemMediaSession.currentAssetId !== expectedAssetId) {
        return false;
      }
      try {
        await session.setAVMetadata(metadata);
        return true;
      } catch (err) {
        if (i + 1 >= maxAttempts) {
          Logger.warn('SystemMediaSession', `setAVMetadata failed after retries: ${(err as Error).message}`);
          return false;
        }
        await SystemMediaSession.delayMs(METADATA_RETRY_DELAY_MS);
      }
    }
    return false;
  }

  private static async delayMs(ms: number): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
}
