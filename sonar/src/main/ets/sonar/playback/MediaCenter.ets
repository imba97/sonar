import { common } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { Logger } from '../common/Logger';
import { NowPlayingTrack, PlaybackSnapshot } from './PlaybackSnapshot';

export interface MediaCenterCommands {
  onPlay: () => Promise<void>;
  onPause: () => Promise<void>;
  onNext: () => Promise<void>;
  onPrevious: () => Promise<void>;
  onSeek: (positionMs: number) => Promise<void>;
}

export class MediaCenter {
  private context: common.UIAbilityContext | null = null;
  private session: avSession.AVSession | null = null;
  private commands: MediaCenterCommands | null = null;
  private eventsRegistered: boolean = false;
  private activated: boolean = false;
  private lastAssetId: string = '';
  private lastPlaybackSyncSecond: number = -1;
  private lastPlaybackStateIsPlaying: boolean = false;
  private lastPlaybackStateSyncAt: number = 0;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setCommands(commands: MediaCenterCommands): void {
    this.commands = commands;
  }

  async apply(snapshot: PlaybackSnapshot, cover: image.PixelMap | null): Promise<void> {
    const session: avSession.AVSession | null = await this.ensureSession();
    if (session === null) {
      return;
    }
    const track = snapshot.track;
    if (track === null) {
      this.lastAssetId = '';
      try {
        await session.setAVPlaybackState({
          state: avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
          speed: 1.0,
          position: { elapsedTime: 0, updateTime: Date.now() }
        });
      } catch (err) {
        Logger.warn('MediaCenter', `clear state failed: ${(err as Error).message}`);
      }
      return;
    }
    if (track.id !== this.lastAssetId) {
      this.lastAssetId = track.id;
      const metadata: avSession.AVMetadata = MediaCenter.buildMetadata(track, cover);
      try {
        await session.setAVMetadata(metadata);
      } catch (err) {
        Logger.warn('MediaCenter', `setAVMetadata failed: ${(err as Error).message}`);
      }
      await this.pushPlaybackState(snapshot, true);
      if (!this.activated) {
        try {
          await session.activate();
          this.activated = true;
        } catch (err) {
          Logger.warn('MediaCenter', `activate failed: ${(err as Error).message}`);
        }
      }
      return;
    }
    if (cover !== null) {
      const metadata: avSession.AVMetadata = MediaCenter.buildMetadata(track, cover);
      try {
        await session.setAVMetadata(metadata);
      } catch (err) {
        Logger.warn('MediaCenter', `setAVMetadata cover refresh failed: ${(err as Error).message}`);
      }
    }
    await this.pushPlaybackState(snapshot, false);
    if (!this.activated) {
      try {
        await session.activate();
        this.activated = true;
      } catch (err) {
        Logger.warn('MediaCenter', `activate failed: ${(err as Error).message}`);
      }
    }
  }

  async release(): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      await this.session.deactivate();
    } catch (err) {
      Logger.warn('MediaCenter', `deactivate failed: ${(err as Error).message}`);
    }
    this.session = null;
    this.eventsRegistered = false;
    this.activated = false;
    this.lastAssetId = '';
    this.lastPlaybackSyncSecond = -1;
  }

  private static buildMetadata(track: NowPlayingTrack, cover: image.PixelMap | null): avSession.AVMetadata {
    if (cover !== null) {
      return {
        assetId: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.durationMs,
        mediaImage: cover
      };
    }
    return {
      assetId: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.durationMs
    };
  }

  private async pushPlaybackState(snapshot: PlaybackSnapshot, force: boolean): Promise<void> {
    const session: avSession.AVSession | null = this.session;
    if (session === null) {
      return;
    }
    const isPlaying: boolean = snapshot.phase === 'playing';
    const positionMs: number = snapshot.positionMs;
    const now: number = Date.now();
    const currentSecond: number = Math.floor(positionMs / 1000);
    if (!force && isPlaying && currentSecond === this.lastPlaybackSyncSecond) {
      return;
    }
    if (!force && isPlaying === this.lastPlaybackStateIsPlaying &&
      now - this.lastPlaybackStateSyncAt < 1000) {
      return;
    }
    let state: avSession.PlaybackState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    if (snapshot.phase === 'playing') {
      state = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    } else if (snapshot.phase === 'loading') {
      state = avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
    }
    try {
      await session.setAVPlaybackState({
        state,
        speed: 1.0,
        position: {
          elapsedTime: positionMs,
          updateTime: Date.now()
        }
      });
      this.lastPlaybackStateSyncAt = now;
      this.lastPlaybackStateIsPlaying = isPlaying;
      this.lastPlaybackSyncSecond = currentSecond;
    } catch (err) {
      Logger.warn('MediaCenter', `setAVPlaybackState failed: ${(err as Error).message}`);
    }
  }

  private async ensureSession(): Promise<avSession.AVSession | null> {
    if (this.session !== null) {
      return this.session;
    }
    if (this.context === null) {
      return null;
    }
    try {
      const created: avSession.AVSession =
        await avSession.createAVSession(this.context, 'sonar_audio_session', 'audio');
      this.registerEvents(created);
      this.session = created;
      try {
        created.off('toggleFavorite');
      } catch (_err) {
      }
      return created;
    } catch (err) {
      Logger.warn('MediaCenter', `createAVSession failed: ${(err as Error).message}`);
      return null;
    }
  }

  private registerEvents(session: avSession.AVSession): void {
    if (this.eventsRegistered) {
      return;
    }
    try {
      session.on('play', () => {
        if (this.commands !== null) {
          void this.commands.onPlay();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register play failed: ${(err as Error).message}`);
    }
    try {
      session.on('pause', () => {
        if (this.commands !== null) {
          void this.commands.onPause();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register pause failed: ${(err as Error).message}`);
    }
    try {
      session.on('playNext', () => {
        if (this.commands !== null) {
          void this.commands.onNext();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register playNext failed: ${(err as Error).message}`);
    }
    try {
      session.on('playPrevious', () => {
        if (this.commands !== null) {
          void this.commands.onPrevious();
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register playPrevious failed: ${(err as Error).message}`);
    }
    try {
      session.on('seek', (timeMs: number) => {
        if (this.commands !== null) {
          void this.commands.onSeek(timeMs);
        }
      });
    } catch (err) {
      Logger.warn('MediaCenter', `register seek failed: ${(err as Error).message}`);
    }
    this.eventsRegistered = true;
  }
}
