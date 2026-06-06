import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { Album, Song, SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';
import { EndpointChangeEvent } from '../network/routing/EndpointTypes';
import { MediaResourceService } from '../network/media/MediaResourceService';
import { StreamResource } from '../network/media/StreamResource';
import { PlaybackPipeline } from './pipeline/PlaybackPipeline';
import { BackgroundPlayback } from './BackgroundPlayback';
import { CoverCache } from './CoverCache';
import { MediaCenter, MediaCenterCommands } from './MediaCenter';
import { resolveNextIndex, resolvePreviousIndex } from './PlaybackModeResolver';
import {
  buildNowPlayingTrack,
  NowPlayingTrack,
  PlaybackMode,
  PlaybackPhase,
  PlaybackSnapshot
} from './PlaybackSnapshot';
import { PlaybackStore } from './PlaybackStore';
import { PlaybackSwitch, PlaybackSwitchHost } from './PlaybackSwitch';
import { EnginePhase, PcmPlaybackEngine, PcmPlaybackEngineListener } from './PcmPlaybackEngine';
import { PcmRingBuffer } from './PcmRingBuffer';
import { StreamDecoder } from './StreamDecoder';

const HEARTBEAT_INTERVAL_MS: number = 15_000;
const MIN_SCROBBLE_TRACK_LENGTH_MS: number = 30_000;
const MAX_SCROBBLE_PROGRESS_THRESHOLD_MS: number = 240_000;
const RING_CAPACITY_BYTES: number = 1024 * 1024 * 2;

export interface SystemTransportHandler {
  playNext(manual: boolean): Promise<void>;
  playPrevious(): Promise<void>;
  seekTo(positionMs: number): Promise<void>;
  toggle(): Promise<void>;
}

class SessionEngineListener implements PcmPlaybackEngineListener {
  onPhaseChanged(phase: EnginePhase): void {
    PlaybackSession.getInstance().onEnginePhase(phase);
  }

  onPositionChanged(_positionMs: number): void {
    PlaybackSession.getInstance().onEnginePosition();
  }

  onDurationChanged(durationMs: number): void {
    PlaybackSession.getInstance().onEngineDuration(durationMs);
  }

  onCompleted(): void {
    void PlaybackSession.getInstance().handleTrackCompleted();
  }

  onError(message: string): void {
    PlaybackSession.getInstance().handleEngineError(message);
  }
}

class SessionMediaCenterCommands implements MediaCenterCommands {
  private readonly session: PlaybackSession;

  constructor(session: PlaybackSession) {
    this.session = session;
  }

  async onPlay(): Promise<void> {
    await this.session.handleSystemPlay();
  }

  async onPause(): Promise<void> {
    await this.session.handleSystemPause();
  }

  async onNext(): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.playNext(true);
    }
  }

  async onPrevious(): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.playPrevious();
    }
  }

  async onSeek(positionMs: number): Promise<void> {
    const handler: SystemTransportHandler | null = this.session.getTransportHandler();
    if (handler !== null) {
      await handler.seekTo(positionMs);
    }
  }
}

export class PlaybackSession implements PlaybackSwitchHost {
  private static instance: PlaybackSession | null = null;

  private initialized: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private readonly engine: PcmPlaybackEngine = new PcmPlaybackEngine();
  private readonly decoder: StreamDecoder = new StreamDecoder();
  private readonly ring: PcmRingBuffer = new PcmRingBuffer(RING_CAPACITY_BYTES);
  private readonly mediaCenter: MediaCenter = new MediaCenter();
  private queue: Song[] = [];
  private currentIndex: number = -1;
  private currentMode: PlaybackMode = 'listLoop';
  private coverRevision: number = 0;
  private currentCover: image.PixelMap | null = null;
  private currentCoverId: string = '';
  private heartbeatTimerId: number = -1;
  private handlingCompletion: boolean = false;
  private systemCommandInFlight: boolean = false;
  private albumCoverFallbackId: string = '';
  private snapshot: PlaybackSnapshot = PlaybackSnapshot.idle();
  private previewTrack: NowPlayingTrack | null = null;
  private transportHandler: SystemTransportHandler | null = null;
  private lastMediaCenterPositionAt: number = 0;
  private activeStreamResource: StreamResource | null = null;
  private networkMigrating: boolean = false;

  private readonly engineListener: PcmPlaybackEngineListener = new SessionEngineListener();

  static getInstance(): PlaybackSession {
    if (PlaybackSession.instance === null) {
      PlaybackSession.instance = new PlaybackSession();
    }
    return PlaybackSession.instance;
  }

  setTransportHandler(handler: SystemTransportHandler): void {
    this.transportHandler = handler;
  }

  getTransportHandler(): SystemTransportHandler | null {
    return this.transportHandler;
  }

  getCurrentMode(): PlaybackMode {
    return this.currentMode;
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    CoverCache.setContext(context);
    BackgroundPlayback.setContext(context);
    this.decoder.setContext(context);
    this.mediaCenter.setContext(context);
    this.mediaCenter.setCommands(new SessionMediaCenterCommands(this));
    if (this.initialized) {
      return;
    }
    PlaybackStore.init(PlaybackSnapshot.idle());
    this.engine.setListener(this.engineListener);
    await this.engine.initialize();
    PlaybackPipeline.setNetworkPathChangedHandler((event: EndpointChangeEvent) => {
      return this.handleNetworkPathChanged(event);
    });
    this.initialized = true;
  }

  setContext(context: common.UIAbilityContext): void {
    void this.initialize(context);
  }

  async release(): Promise<void> {
    this.stopHeartbeat();
    this.systemCommandInFlight = false;
    await this.submitCurrentTrackCompletion('release');
    await this.engine.stop();
    await this.engine.release();
    this.ring.clear();
    this.decoder.reset();
    await BackgroundPlayback.release();
    await this.mediaCenter.release();
    await CoverCache.releaseAll();
    this.releaseActiveStream();
    this.releaseCover();
    this.queue = [];
    this.currentIndex = -1;
    this.previewTrack = null;
    this.initialized = false;
    this.snapshot = PlaybackSnapshot.idle();
    PlaybackStore.publish(this.snapshot);
  }

  togglePlaybackMode(): PlaybackMode {
    if (this.currentMode === 'listLoop') {
      this.currentMode = 'singleLoop';
    } else if (this.currentMode === 'singleLoop') {
      this.currentMode = 'random';
    } else {
      this.currentMode = 'listLoop';
    }
    this.publishSnapshot(this.snapshot.phase, true);
    return this.currentMode;
  }

  async playQueue(songs: Song[], index: number, albumCoverArtId?: string): Promise<void> {
    if (songs.length === 0) {
      return;
    }
    this.albumCoverFallbackId = albumCoverArtId ?? '';
    const safeIndex: number = index >= 0 && index < songs.length ? index : 0;
    const targetSong: Song = songs[safeIndex];
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(targetSong, this.albumCoverFallbackId);
    await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
    this.queue = songs.map((item: Song) => item);
    this.currentIndex = safeIndex;
    await PlaybackSwitch.commitSwitch(this, true);
  }

  async playAlbumAll(album: Album): Promise<void> {
    await PlaybackSwitch.prepareSwitchFromAlbum(this, album);
    try {
      const resp = await SubsonicClient.getInstance().getAlbum(album.id);
      const songs: Song[] = resp.album.song ?? [];
      if (songs.length === 0) {
        throw new Error('EMPTY_ALBUM');
      }
      const coverArt: string = album.coverArt ?? resp.album.coverArt ?? '';
      await this.playQueue(songs, 0, coverArt);
    } catch (err) {
      PlaybackSwitch.restoreFailedSwitch(this);
      throw err as Error;
    }
  }

  async enqueueNext(song: Song): Promise<void> {
    if (this.queue.length === 0 || this.currentIndex < 0) {
      this.queue = [song];
      this.currentIndex = 0;
      this.albumCoverFallbackId = song.coverArt ?? this.albumCoverFallbackId;
      const previewTrack: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
      await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
      await PlaybackSwitch.commitSwitch(this, true);
      return;
    }
    const nextInsertIndex: number = this.currentIndex + 1;
    const before: Song[] = this.queue.slice(0, nextInsertIndex);
    const after: Song[] = this.queue.slice(nextInsertIndex);
    this.queue = [...before, song, ...after];
  }

  async toggle(): Promise<void> {
    const phase: EnginePhase = this.engine.getPhase();
    if (phase === 'playing') {
      await this.engine.pause();
      return;
    }
    if (this.getCurrentSong() === null && this.queue.length > 0) {
      await PlaybackSwitch.commitSwitch(this, true);
      return;
    }
    await this.engine.play();
    const song: Song | null = this.getCurrentSong();
    if (song !== null) {
      try {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, this.engine.getPositionMs());
      } catch (err) {
        Logger.warn('PlaybackSession', `resume nowPlaying failed: ${this.classifyScrobbleError(err as Error)}`);
      }
    }
  }

  async playNext(manual: boolean = true): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }
    const nextIndex: number = resolveNextIndex(this.queue, this.currentIndex, this.currentMode, manual);
    const nextSong: Song = this.queue[nextIndex];
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(nextSong, this.albumCoverFallbackId);
    await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
    this.currentIndex = nextIndex;
    await PlaybackSwitch.commitSwitch(this, true);
  }

  async playPrevious(): Promise<void> {
    if (this.queue.length === 0) {
      return;
    }
    const prevIndex: number = resolvePreviousIndex(this.queue, this.currentIndex);
    const prevSong: Song = this.queue[prevIndex];
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(prevSong, this.albumCoverFallbackId);
    await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
    this.currentIndex = prevIndex;
    await PlaybackSwitch.commitSwitch(this, true);
  }

  async seekTo(positionMs: number): Promise<void> {
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      return;
    }
    let maxDurationMs: number = track.durationMs;
    if (maxDurationMs <= 0) {
      maxDurationMs = this.engine.getDurationMs();
    }
    let safe: number = positionMs;
    if (safe < 0) {
      safe = 0;
    }
    if (maxDurationMs > 0 && safe > maxDurationMs) {
      safe = maxDurationMs;
    }
    await this.engine.seek(safe);
    this.publishSnapshot(this.snapshot.phase, true);
  }

  buildPreviewTrackFromAlbum(album: Album): NowPlayingTrack {
    const albumTitle: string = album.title ?? album.name ?? '未知专辑';
    return new NowPlayingTrack(
      album.id,
      albumTitle,
      album.artist.length > 0 ? album.artist : '未知歌手',
      albumTitle,
      album.coverArt ?? '',
      0
    );
  }

  lockPreview(track: NowPlayingTrack, albumCoverArtId?: string): void {
    if (albumCoverArtId !== undefined && albumCoverArtId.length > 0) {
      this.albumCoverFallbackId = albumCoverArtId;
    }
    this.previewTrack = track;
    this.coverRevision += 1;
    this.publishSnapshot('loading', true);
    if (track.coverArtId.length > 0) {
      void this.ensureCover(track.coverArtId);
    }
  }

  clearPreview(): void {
    this.previewTrack = null;
  }

  restoreSnapshotFromEngine(): void {
    const enginePhase: EnginePhase = this.engine.getPhase();
    let playbackPhase: PlaybackPhase = 'idle';
    if (enginePhase === 'loading') {
      playbackPhase = 'loading';
    } else if (enginePhase === 'playing') {
      playbackPhase = 'playing';
    } else if (enginePhase === 'paused') {
      playbackPhase = 'paused';
    } else if (enginePhase === 'error') {
      playbackPhase = 'error';
    }
    this.publishSnapshot(playbackPhase, true);
  }

  async submitCurrentTrackCompletionOnSwitch(): Promise<void> {
    await this.submitCurrentTrackCompletion('switch');
  }

  async stopEngineAndClearBuffers(): Promise<void> {
    await this.engine.stop();
    this.ring.clear();
    this.decoder.reset();
    this.releaseActiveStream();
  }

  private releaseActiveStream(): void {
    if (this.activeStreamResource !== null) {
      this.activeStreamResource.cancelToken.cancel();
      this.activeStreamResource = null;
    }
  }

  async loadCurrentSongStream(reportStart: boolean): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      await this.engine.stop();
      this.releaseCover();
      this.currentIndex = -1;
      this.clearPreview();
      this.publishSnapshot('idle', true);
      await BackgroundPlayback.stop();
      return;
    }
    this.clearPreview();
    const track: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
    this.publishSnapshot('loading', true);
    this.releaseActiveStream();
    this.activeStreamResource = MediaResourceService.openStream(song.id);
    const streamUrl: string = this.activeStreamResource.resolveRequest().url;
    PlaybackPipeline.onTrackStarted(song.id);
    const coverTask: Promise<image.PixelMap | null> = this.ensureCover(track.coverArtId);
    try {
      await this.engine.loadStreamUrl(streamUrl, true);
      if (reportStart) {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, 0);
      }
    } catch (err) {
      this.publishSnapshot('error', true);
      Logger.error('PlaybackSession', `play failed: ${(err as Error).message}`);
      return;
    }
    await coverTask;
    this.publishSnapshot('loading', true);
  }

  private async handleNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    if (this.networkMigrating) {
      return;
    }
    const song: Song | null = this.getCurrentSong();
    if (song === null || this.activeStreamResource === null) {
      return;
    }
    const phase: PlaybackPhase = this.snapshot.phase;
    if (phase !== 'playing' && phase !== 'paused' && phase !== 'loading') {
      return;
    }
    this.networkMigrating = true;
    const positionMs: number = this.engine.getPositionMs();
    const wasPlaying: boolean = phase === 'playing';
    try {
      Logger.info('PlaybackSession',
        `migrate stream ${event.from}->${event.to} song=${song.id} pos=${positionMs}`);
      const streamUrl: string = this.activeStreamResource.resolveRequest().url;
      await this.engine.loadStreamUrl(streamUrl, wasPlaying);
      if (positionMs > 0) {
        await this.engine.seek(positionMs);
      }
    } catch (err) {
      Logger.warn('PlaybackSession', `network migrate failed: ${(err as Error).message}`);
    } finally {
      this.networkMigrating = false;
    }
  }

  handleEngineError(message: string): void {
    Logger.warn('PlaybackSession', message);
    this.publishSnapshot('error');
  }

  onEnginePhase(phase: EnginePhase): void {
    let playbackPhase: PlaybackPhase = 'idle';
    if (phase === 'loading') {
      playbackPhase = 'loading';
    } else if (phase === 'playing') {
      playbackPhase = 'playing';
      this.startHeartbeat();
    } else if (phase === 'paused') {
      playbackPhase = 'paused';
      this.stopHeartbeat();
    } else if (phase === 'error') {
      playbackPhase = 'error';
      this.stopHeartbeat();
    } else {
      playbackPhase = 'idle';
      this.stopHeartbeat();
    }
    this.publishSnapshot(playbackPhase, true);
    void this.syncMediaCenter(this.snapshot, true);
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      void BackgroundPlayback.stop();
      return;
    }
    if (playbackPhase === 'playing') {
      void BackgroundPlayback.start(track.title, track.artist, true);
      return;
    }
    if (playbackPhase === 'paused' || playbackPhase === 'idle' || playbackPhase === 'error') {
      void BackgroundPlayback.update(track.title, track.artist, false);
    }
  }

  onEnginePosition(): void {
    if (this.previewTrack !== null) {
      return;
    }
    if (this.snapshot.phase !== 'loading') {
      this.publishSnapshot(this.snapshot.phase, false);
    }
    const now: number = Date.now();
    if (now - this.lastMediaCenterPositionAt < 1000) {
      return;
    }
    this.lastMediaCenterPositionAt = now;
    void this.mediaCenter.syncPlaybackState(this.snapshot);
  }

  onEngineDuration(durationMs: number): void {
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      return;
    }
    const updated: NowPlayingTrack = new NowPlayingTrack(
      track.id,
      track.title,
      track.artist,
      track.album,
      track.coverArtId,
      durationMs > 0 ? durationMs : track.durationMs
    );
    this.snapshot = new PlaybackSnapshot(
      updated,
      this.snapshot.phase,
      this.snapshot.positionMs,
      this.currentMode,
      this.currentIndex >= 0,
      this.coverRevision
    );
    PlaybackStore.publish(this.snapshot);
    if (durationMs > 0) {
      void this.syncMediaCenter(this.snapshot, true);
    }
  }

  private publishSnapshot(phase: PlaybackPhase, forceMedia: boolean = false): void {
    let track: NowPlayingTrack | null = null;
    let positionMs: number = 0;
    let showMiniPlayer: boolean = this.currentIndex >= 0;
    let snapshotPhase: PlaybackPhase = phase;

    if (this.previewTrack !== null) {
      track = this.previewTrack;
      snapshotPhase = 'loading';
      positionMs = 0;
      showMiniPlayer = true;
    } else {
      const song: Song | null = this.getCurrentSong();
      if (song !== null) {
        track = buildNowPlayingTrack(song, this.albumCoverFallbackId);
        if (this.engine.getDurationMs() > 0) {
          track = new NowPlayingTrack(
            track.id,
            track.title,
            track.artist,
            track.album,
            track.coverArtId,
            this.engine.getDurationMs()
          );
        }
      }
      positionMs = this.engine.getPositionMs();
    }

    this.snapshot = new PlaybackSnapshot(
      track,
      snapshotPhase,
      positionMs,
      this.currentMode,
      showMiniPlayer,
      this.coverRevision
    );
    PlaybackStore.publish(this.snapshot);
    if (forceMedia) {
      void this.syncMediaCenter(this.snapshot, true);
    }
  }

  private async syncMediaCenter(snapshot: PlaybackSnapshot, force: boolean): Promise<void> {
    let cover: image.PixelMap | null = null;
    if (snapshot.track !== null && snapshot.track.coverArtId.length > 0) {
      CoverCache.pin(snapshot.track.coverArtId);
      cover = CoverCache.getDisplaySource(snapshot.track.coverArtId).pixelMap;
      if (cover === null) {
        cover = await CoverCache.load(snapshot.track.coverArtId);
        if (cover !== null) {
          this.coverRevision = CoverCache.getRevision();
        }
      }
      this.currentCover = cover;
      this.currentCoverId = snapshot.track.coverArtId;
    } else {
      this.releaseCover();
    }
    await this.mediaCenter.apply(snapshot, cover);
  }

  private async ensureCover(coverArtId: string): Promise<image.PixelMap | null> {
    if (coverArtId.length === 0) {
      return null;
    }
    const existing: image.PixelMap | null = CoverCache.getDisplaySource(coverArtId).pixelMap;
    if (existing !== null) {
      this.coverRevision = CoverCache.getRevision();
      return existing;
    }
    const loaded: image.PixelMap | null = await CoverCache.load(coverArtId);
    if (loaded !== null) {
      this.coverRevision = CoverCache.getRevision();
      this.publishSnapshot(this.snapshot.phase, true);
    }
    return loaded;
  }

  private releaseCover(): void {
    CoverCache.unpin();
    this.currentCover = null;
    this.currentCoverId = '';
  }

  async handleSystemPlay(): Promise<void> {
    if (this.systemCommandInFlight) {
      return;
    }
    this.systemCommandInFlight = true;
    try {
      if (this.engine.getPhase() !== 'playing') {
        if (this.getCurrentSong() === null && this.queue.length > 0) {
          await PlaybackSwitch.commitSwitch(this, true);
        } else {
          await this.engine.play();
        }
      }
    } finally {
      this.systemCommandInFlight = false;
    }
  }

  async handleSystemPause(): Promise<void> {
    if (this.systemCommandInFlight) {
      return;
    }
    this.systemCommandInFlight = true;
    try {
      if (this.engine.getPhase() === 'playing') {
        await this.engine.pause();
      }
    } finally {
      this.systemCommandInFlight = false;
    }
  }

  async handleTrackCompleted(): Promise<void> {
    if (this.handlingCompletion) {
      return;
    }
    this.handlingCompletion = true;
    await this.submitCurrentTrackCompletion('completed');
    if (this.queue.length === 0) {
      this.handlingCompletion = false;
      return;
    }
    if (this.currentMode === 'singleLoop') {
      const song: Song | null = this.getCurrentSong();
      if (song !== null) {
        const previewTrack: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
        await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
        await PlaybackSwitch.commitSwitch(this, true);
      }
      this.handlingCompletion = false;
      return;
    }
    const nextIndex: number = resolveNextIndex(this.queue, this.currentIndex, this.currentMode, false);
    const nextSong: Song = this.queue[nextIndex];
    const previewTrack: NowPlayingTrack = buildNowPlayingTrack(nextSong, this.albumCoverFallbackId);
    await PlaybackSwitch.prepareSwitch(this, previewTrack, this.albumCoverFallbackId);
    this.currentIndex = nextIndex;
    await PlaybackSwitch.commitSwitch(this, true);
    this.handlingCompletion = false;
  }

  private getCurrentSong(): Song | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.queue.length) {
      return null;
    }
    return this.queue[this.currentIndex];
  }

  stopHeartbeat(): void {
    if (this.heartbeatTimerId >= 0) {
      clearInterval(this.heartbeatTimerId);
      this.heartbeatTimerId = -1;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimerId = setInterval(() => {
      void this.reportHeartbeat();
    }, HEARTBEAT_INTERVAL_MS);
  }

  private async reportHeartbeat(): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null || this.snapshot.phase !== 'playing') {
      return;
    }
    try {
      await SubsonicClient.getInstance().reportNowPlaying(song.id, this.engine.getPositionMs());
    } catch (err) {
      Logger.warn('PlaybackSession', `heartbeat failed: ${this.classifyScrobbleError(err as Error)}`);
    }
  }

  private classifyScrobbleError(err: Error): string {
    if (err instanceof SubsonicApiError) {
      if (err.code === -3) {
        return 'auth';
      }
      if (err.code === 0) {
        return 'network';
      }
    }
    return 'unknown';
  }

  private async submitCurrentTrackCompletion(reason: string): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null) {
      return;
    }
    const durationMs: number = song.duration > 0 ? song.duration * 1000 : this.engine.getDurationMs();
    let playedMs: number = this.engine.getPositionMs();
    if (playedMs < 0) {
      playedMs = 0;
    }
    if (durationMs > 0 && playedMs > durationMs) {
      playedMs = durationMs;
    }
    if (durationMs > 0 && durationMs <= MIN_SCROBBLE_TRACK_LENGTH_MS) {
      return;
    }
    if (durationMs <= 0 && playedMs < MIN_SCROBBLE_TRACK_LENGTH_MS) {
      return;
    }
    const thresholdMs: number = durationMs > 0
      ? Math.min(Math.floor(durationMs / 2), MAX_SCROBBLE_PROGRESS_THRESHOLD_MS)
      : MIN_SCROBBLE_TRACK_LENGTH_MS;
    if (playedMs < thresholdMs) {
      return;
    }
    try {
      await SubsonicClient.getInstance().submitScrobble(song.id, Date.now());
      Logger.debug('PlaybackSession', `scrobble ok reason=${reason} id=${song.id}`);
    } catch (err) {
      Logger.warn('PlaybackSession', `scrobble failed: ${(err as Error).message}`);
    }
  }
}
