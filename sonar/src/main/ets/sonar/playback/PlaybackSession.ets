import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { Song, SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';
import { BackgroundPlaybackService } from './BackgroundPlaybackService';
import { SystemMediaSession } from './SystemMediaSession';

const HEARTBEAT_INTERVAL_MS: number = 15_000;
const MIN_SCROBBLE_TRACK_LENGTH_MS: number = 30_000;
const MAX_SCROBBLE_PROGRESS_THRESHOLD_MS: number = 240_000;

export type PlaybackMode = 'listLoop' | 'singleLoop' | 'random';

export class PlaybackSession {
  private static initialized: boolean = false;
  private static player: media.AVPlayer | null = null;
  private static queue: Song[] = [];
  private static currentIndex: number = -1;
  private static heartbeatTimerId: number = -1;
  private static latestProgressMs: number = 0;
  private static latestDurationMs: number = 0;
  private static pendingAutoPlay: boolean = false;
  private static handlingCompletion: boolean = false;
  private static currentMode: PlaybackMode = 'listLoop';
  private static systemCommandInFlight: boolean = false;

  static async initialize(context?: common.UIAbilityContext): Promise<void> {
    if (PlaybackSession.initialized) {
      if (context !== undefined) {
        PlaybackSession.setContext(context);
      }
      return;
    }
    if (context !== undefined) {
      PlaybackSession.setContext(context);
    }
    AppStorage.setOrCreate<boolean>('showMiniPlayer', false);
    AppStorage.setOrCreate<boolean>('bottomDockSwapped', false);
    AppStorage.setOrCreate<string>('nowPlayingSongId', '');
    AppStorage.setOrCreate<string>('nowPlayingTitle', '');
    AppStorage.setOrCreate<string>('nowPlayingArtist', '');
    AppStorage.setOrCreate<string>('nowPlayingCoverArt', '');
    AppStorage.setOrCreate<boolean>('isPlaying', false);
    AppStorage.setOrCreate<string>('playbackMode', PlaybackSession.currentMode);
    AppStorage.setOrCreate<number>('playbackProgressMs', 0);
    AppStorage.setOrCreate<number>('playbackDurationMs', 0);
    await PlaybackSession.ensurePlayer();
    PlaybackSession.initialized = true;
  }

  static setContext(context: common.UIAbilityContext): void {
    BackgroundPlaybackService.setContext(context);
    SystemMediaSession.setContext(context);
    SystemMediaSession.setCallbacks({
      onPlay: async () => {
        await PlaybackSession.handleSystemPlay();
      },
      onPause: async () => {
        await PlaybackSession.handleSystemPause();
      },
      onNext: async () => {
        await PlaybackSession.playNext(true);
      },
      onPrevious: async () => {
        await PlaybackSession.playPrevious();
      },
      onSeek: async (positionMs: number) => {
        await PlaybackSession.seekTo(positionMs);
      }
    });
  }

  static async release(): Promise<void> {
    PlaybackSession.stopHeartbeat();
    PlaybackSession.systemCommandInFlight = false;
    await PlaybackSession.submitCurrentTrackCompletion('release');
    const player: media.AVPlayer | null = PlaybackSession.player;
    if (player !== null) {
      try {
        await player.release();
      } catch (err) {
        Logger.warn('PlaybackSession', `release player failed: ${(err as Error).message}`);
      }
    }
    PlaybackSession.player = null;
    PlaybackSession.initialized = false;
    PlaybackSession.queue = [];
    PlaybackSession.currentIndex = -1;
    PlaybackSession.pendingAutoPlay = false;
    PlaybackSession.handlingCompletion = false;
    PlaybackSession.syncAppStorageBaseState(false);
    PlaybackSession.syncNowPlayingMeta(null);
    await BackgroundPlaybackService.release();
    await SystemMediaSession.release();
  }

  static getCurrentMode(): PlaybackMode {
    return PlaybackSession.currentMode;
  }

  static togglePlaybackMode(): PlaybackMode {
    if (PlaybackSession.currentMode === 'listLoop') {
      PlaybackSession.currentMode = 'singleLoop';
    } else if (PlaybackSession.currentMode === 'singleLoop') {
      PlaybackSession.currentMode = 'random';
    } else {
      PlaybackSession.currentMode = 'listLoop';
    }
    AppStorage.setOrCreate<string>('playbackMode', PlaybackSession.currentMode);
    return PlaybackSession.currentMode;
  }

  static async playFromList(songs: Song[], index: number): Promise<void> {
    if (songs.length === 0) {
      return;
    }
    await PlaybackSession.submitCurrentTrackCompletionOnSwitch();
    const safeIndex: number = index >= 0 && index < songs.length ? index : 0;
    PlaybackSession.queue = songs.map((item: Song) => item);
    PlaybackSession.currentIndex = safeIndex;
    await PlaybackSession.playCurrentSong(true);
  }

  static async enqueueNext(song: Song): Promise<void> {
    if (PlaybackSession.queue.length === 0 || PlaybackSession.currentIndex < 0) {
      PlaybackSession.queue = [song];
      PlaybackSession.currentIndex = 0;
      await PlaybackSession.playCurrentSong(true);
      return;
    }
    const nextInsertIndex: number = PlaybackSession.currentIndex + 1;
    const before: Song[] = PlaybackSession.queue.slice(0, nextInsertIndex);
    const after: Song[] = PlaybackSession.queue.slice(nextInsertIndex);
    PlaybackSession.queue = [...before, song, ...after];
  }

  static async togglePlayPause(): Promise<void> {
    const player: media.AVPlayer = await PlaybackSession.ensurePlayer();
    const isPlaying: boolean = player.state === 'playing';
    if (isPlaying) {
      try {
        await player.pause();
        PlaybackSession.syncAppStorageBaseState(false);
        await PlaybackSession.syncSystemPlaybackStatus(false);
      } catch (err) {
        Logger.warn('PlaybackSession', `pause failed: ${(err as Error).message}`);
      }
      return;
    }
    if (PlaybackSession.getCurrentSong() === null && PlaybackSession.queue.length > 0) {
      await PlaybackSession.playCurrentSong(true);
      return;
    }
    try {
      await player.play();
      PlaybackSession.syncAppStorageBaseState(true);
      await PlaybackSession.syncSystemPlaybackStatus(true);
      const currentSong: Song | null = PlaybackSession.getCurrentSong();
      if (currentSong !== null) {
        try {
          await SubsonicClient.getInstance().reportNowPlaying(currentSong.id, PlaybackSession.latestProgressMs);
        } catch (err) {
          Logger.warn('PlaybackSession',
            `resume nowPlaying failed [${PlaybackSession.classifyScrobbleError(err as Error)}]: ${(err as Error).message}`);
        }
      }
    } catch (err) {
      Logger.warn('PlaybackSession', `resume failed: ${(err as Error).message}`);
    }
  }

  static async playNext(manual: boolean = true): Promise<void> {
    if (PlaybackSession.queue.length === 0) {
      return;
    }
    await PlaybackSession.submitCurrentTrackCompletionOnSwitch();
    const nextIndex: number = PlaybackSession.resolveNextIndex(manual);
    PlaybackSession.currentIndex = nextIndex;
    await PlaybackSession.playCurrentSong(true);
  }

  static async playPrevious(): Promise<void> {
    if (PlaybackSession.queue.length === 0) {
      return;
    }
    await PlaybackSession.submitCurrentTrackCompletionOnSwitch();
    const queueSize: number = PlaybackSession.queue.length;
    if (queueSize === 1) {
      PlaybackSession.currentIndex = 0;
      await PlaybackSession.playCurrentSong(true);
      return;
    }
    let prevIndex: number = PlaybackSession.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = queueSize - 1;
    }
    PlaybackSession.currentIndex = prevIndex;
    await PlaybackSession.playCurrentSong(true);
  }

  static async seekTo(positionMs: number): Promise<void> {
    const player: media.AVPlayer | null = PlaybackSession.player;
    if (player === null) {
      return;
    }
    const durationMs: number = AppStorage.get<number>('playbackDurationMs') ?? PlaybackSession.latestDurationMs;
    if (durationMs <= 0) {
      return;
    }
    const maxDuration: number = durationMs;
    let safePosition: number = positionMs;
    if (safePosition < 0) {
      safePosition = 0;
    }
    if (safePosition > maxDuration) {
      safePosition = maxDuration;
    }
    try {
      await player.seek(safePosition);
      PlaybackSession.latestProgressMs = safePosition;
      AppStorage.setOrCreate<number>('playbackProgressMs', safePosition);
      void SystemMediaSession.syncPlaybackState(safePosition, player.state === 'playing', true);
    } catch (err) {
      Logger.warn('PlaybackSession', `seek failed: ${(err as Error).message}`);
    }
  }

  private static async ensurePlayer(): Promise<media.AVPlayer> {
    if (PlaybackSession.player !== null) {
      return PlaybackSession.player;
    }
    try {
      const createdPlayer: media.AVPlayer = await media.createAVPlayer();
      PlaybackSession.bindPlayerEvents(createdPlayer);
      PlaybackSession.player = createdPlayer;
      return createdPlayer;
    } catch (err) {
      Logger.error('PlaybackSession', `createAVPlayer failed: ${(err as Error).message}`);
      throw new Error(`createAVPlayer failed: ${(err as Error).message}`);
    }
  }

  private static bindPlayerEvents(player: media.AVPlayer): void {
    player.on('stateChange', (state: string) => {
      void PlaybackSession.onPlayerStateChange(state);
    });
    player.on('timeUpdate', (time: number) => {
      PlaybackSession.latestProgressMs = time;
      AppStorage.setOrCreate<number>('playbackProgressMs', time);
      const activeSong: Song | null = PlaybackSession.getCurrentSong();
      if (activeSong !== null) {
        void SystemMediaSession.syncPlaybackState(time, player.state === 'playing');
      }
    });
  }

  private static async onPlayerStateChange(state: string): Promise<void> {
    const player: media.AVPlayer | null = PlaybackSession.player;
    if (player === null) {
      return;
    }
    if (state === 'initialized') {
      try {
        await player.prepare();
      } catch (err) {
        Logger.warn('PlaybackSession', `prepare failed: ${(err as Error).message}`);
      }
      return;
    }
    if (state === 'prepared') {
      if (PlaybackSession.latestDurationMs <= 0) {
        const currentSong: Song | null = PlaybackSession.getCurrentSong();
        if (currentSong !== null && currentSong.duration > 0) {
          PlaybackSession.latestDurationMs = currentSong.duration * 1000;
          AppStorage.setOrCreate<number>('playbackDurationMs', PlaybackSession.latestDurationMs);
        }
      }
      if (PlaybackSession.pendingAutoPlay) {
        PlaybackSession.pendingAutoPlay = false;
        try {
          await player.play();
        } catch (err) {
          Logger.warn('PlaybackSession', `auto play failed: ${(err as Error).message}`);
        }
      }
      return;
    }
    if (state === 'playing') {
      PlaybackSession.syncAppStorageBaseState(true);
      PlaybackSession.startHeartbeat();
      await PlaybackSession.syncSystemPlaybackStatus(true);
      return;
    }
    if (state === 'paused' || state === 'stopped') {
      PlaybackSession.syncAppStorageBaseState(false);
      PlaybackSession.stopHeartbeat();
      await PlaybackSession.syncSystemPlaybackStatus(false);
      return;
    }
    if (state === 'completed') {
      PlaybackSession.syncAppStorageBaseState(false);
      PlaybackSession.stopHeartbeat();
      await PlaybackSession.syncSystemPlaybackStatus(false);
      await PlaybackSession.handleTrackCompleted();
    }
  }

  private static syncAppStorageBaseState(isPlaying: boolean): void {
    const showMiniPlayer: boolean = PlaybackSession.currentIndex >= 0;
    AppStorage.setOrCreate<boolean>('isPlaying', isPlaying);
    AppStorage.setOrCreate<string>('playbackMode', PlaybackSession.currentMode);
    AppStorage.setOrCreate<boolean>('showMiniPlayer', showMiniPlayer);
    if (!showMiniPlayer) {
      AppStorage.setOrCreate<boolean>('bottomDockSwapped', false);
    }
  }

  private static syncNowPlayingMeta(song: Song | null): void {
    if (song === null) {
      AppStorage.setOrCreate<string>('nowPlayingSongId', '');
      AppStorage.setOrCreate<string>('nowPlayingTitle', '');
      AppStorage.setOrCreate<string>('nowPlayingArtist', '');
      AppStorage.setOrCreate<string>('nowPlayingCoverArt', '');
      AppStorage.setOrCreate<number>('playbackProgressMs', 0);
      AppStorage.setOrCreate<number>('playbackDurationMs', 0);
      return;
    }
    AppStorage.setOrCreate<string>('nowPlayingSongId', song.id);
    AppStorage.setOrCreate<string>('nowPlayingTitle', song.title);
    AppStorage.setOrCreate<string>('nowPlayingArtist', song.artist);
    AppStorage.setOrCreate<string>('nowPlayingCoverArt', song.coverArt ?? '');
  }

  private static startHeartbeat(): void {
    PlaybackSession.stopHeartbeat();
    PlaybackSession.heartbeatTimerId = setInterval(() => {
      void PlaybackSession.reportHeartbeat();
    }, HEARTBEAT_INTERVAL_MS);
  }

  private static stopHeartbeat(): void {
    if (PlaybackSession.heartbeatTimerId >= 0) {
      clearInterval(PlaybackSession.heartbeatTimerId);
      PlaybackSession.heartbeatTimerId = -1;
    }
  }

  private static async reportHeartbeat(): Promise<void> {
    const song: Song | null = PlaybackSession.getCurrentSong();
    if (song === null) {
      return;
    }
    const isPlaying: boolean = (AppStorage.get<boolean>('isPlaying') ?? false);
    if (!isPlaying) {
      return;
    }
    try {
      await SubsonicClient.getInstance().reportNowPlaying(song.id, PlaybackSession.latestProgressMs);
    } catch (err) {
      Logger.warn('PlaybackSession',
        `heartbeat nowPlaying failed [${PlaybackSession.classifyScrobbleError(err as Error)}]: ${(err as Error).message}`);
    }
  }

  private static resolveTrackDurationMs(song: Song): number {
    if (song.duration <= 0) {
      return 0;
    }
    return song.duration * 1000;
  }

  private static resolvePlayedDurationMs(song: Song): number {
    const totalDurationMs: number = PlaybackSession.resolveTrackDurationMs(song);
    let playedDurationMs: number = PlaybackSession.latestProgressMs;
    if (playedDurationMs < 0) {
      playedDurationMs = 0;
    }
    if (totalDurationMs > 0 && playedDurationMs > totalDurationMs) {
      playedDurationMs = totalDurationMs;
    }
    return playedDurationMs;
  }

  private static shouldSubmitScrobble(song: Song, playedDurationMs: number): boolean {
    const totalDurationMs: number = PlaybackSession.resolveTrackDurationMs(song);
    if (totalDurationMs > 0 && totalDurationMs <= MIN_SCROBBLE_TRACK_LENGTH_MS) {
      return false;
    }
    if (totalDurationMs <= 0) {
      return playedDurationMs >= MIN_SCROBBLE_TRACK_LENGTH_MS;
    }
    const thresholdMs: number = Math.min(Math.floor(totalDurationMs / 2), MAX_SCROBBLE_PROGRESS_THRESHOLD_MS);
    return playedDurationMs >= thresholdMs;
  }

  private static classifyScrobbleError(err: Error): string {
    if (err instanceof SubsonicApiError) {
      if (err.code === -3) {
        return 'auth';
      }
      if (err.code === 0) {
        return 'network';
      }
      if (err.code >= 500) {
        return 'server';
      }
      if (err.code >= 400) {
        return 'request';
      }
    }
    return 'unknown';
  }

  private static async submitCurrentTrackCompletion(reason: string): Promise<void> {
    const currentSong: Song | null = PlaybackSession.getCurrentSong();
    if (currentSong === null) {
      return;
    }
    const playedDurationMs: number = PlaybackSession.resolvePlayedDurationMs(currentSong);
    if (!PlaybackSession.shouldSubmitScrobble(currentSong, playedDurationMs)) {
      Logger.debug('PlaybackSession',
        `skip submission reason=${reason} songId=${currentSong.id} playedMs=${playedDurationMs}`);
      return;
    }
    const submissionTimeMs: number = Date.now();
    try {
      await SubsonicClient.getInstance().submitScrobble(currentSong.id, submissionTimeMs);
      Logger.debug('PlaybackSession',
        `submitted scrobble reason=${reason} songId=${currentSong.id} time=${submissionTimeMs}`);
    } catch (err) {
      Logger.warn('PlaybackSession',
        `${reason} submission failed [${PlaybackSession.classifyScrobbleError(err as Error)}]: ${(err as Error).message}`);
    }
  }

  private static async submitCurrentTrackCompletionOnSwitch(): Promise<void> {
    await PlaybackSession.submitCurrentTrackCompletion('switch');
  }

  private static getCurrentSong(): Song | null {
    if (PlaybackSession.currentIndex < 0 || PlaybackSession.currentIndex >= PlaybackSession.queue.length) {
      return null;
    }
    return PlaybackSession.queue[PlaybackSession.currentIndex];
  }

  private static async playCurrentSong(reportStartScrobble: boolean): Promise<void> {
    const song: Song | null = PlaybackSession.getCurrentSong();
    if (song === null) {
      PlaybackSession.syncNowPlayingMeta(null);
      PlaybackSession.syncAppStorageBaseState(false);
      await PlaybackSession.syncSystemPlaybackStatus(false);
      return;
    }
    const player: media.AVPlayer = await PlaybackSession.ensurePlayer();
    PlaybackSession.latestProgressMs = 0;
    PlaybackSession.latestDurationMs = song.duration > 0 ? song.duration * 1000 : 0;
    AppStorage.setOrCreate<number>('playbackProgressMs', 0);
    AppStorage.setOrCreate<number>('playbackDurationMs', PlaybackSession.latestDurationMs);
    PlaybackSession.syncNowPlayingMeta(song);
    PlaybackSession.syncAppStorageBaseState(false);
    PlaybackSession.pendingAutoPlay = true;
    PlaybackSession.stopHeartbeat();
    await SystemMediaSession.syncSong(song, 0, PlaybackSession.latestDurationMs, false);
    await BackgroundPlaybackService.update(song.title, song.artist, false);
    try {
      await player.reset();
    } catch (err) {
      Logger.warn('PlaybackSession', `reset player failed: ${(err as Error).message}`);
    }
    try {
      player.url = SubsonicClient.getInstance().getStreamUrl(song.id);
      if (reportStartScrobble) {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, 0);
      }
    } catch (err) {
      PlaybackSession.pendingAutoPlay = false;
      PlaybackSession.syncAppStorageBaseState(false);
      await PlaybackSession.syncSystemPlaybackStatus(false);
      Logger.error('PlaybackSession', `playCurrentSong failed: ${(err as Error).message}`);
    }
  }

  private static async syncSystemPlaybackStatus(isPlaying: boolean): Promise<void> {
    const currentSong: Song | null = PlaybackSession.getCurrentSong();
    if (currentSong === null) {
      await BackgroundPlaybackService.stop();
      await SystemMediaSession.syncPlaybackState(0, false, true);
      return;
    }
    await SystemMediaSession.syncPlaybackState(PlaybackSession.latestProgressMs, isPlaying, true);
    if (isPlaying) {
      await BackgroundPlaybackService.start(currentSong.title, currentSong.artist, true);
      return;
    }
    await BackgroundPlaybackService.stop();
  }

  private static async handleSystemPlay(): Promise<void> {
    if (PlaybackSession.systemCommandInFlight) {
      return;
    }
    PlaybackSession.systemCommandInFlight = true;
    try {
      const player: media.AVPlayer = await PlaybackSession.ensurePlayer();
      if (player.state !== 'playing') {
        if (PlaybackSession.getCurrentSong() === null && PlaybackSession.queue.length > 0) {
          await PlaybackSession.playCurrentSong(true);
        } else {
          await player.play();
          const currentSong: Song | null = PlaybackSession.getCurrentSong();
          if (currentSong !== null) {
            try {
              await SubsonicClient.getInstance().reportNowPlaying(currentSong.id, PlaybackSession.latestProgressMs);
            } catch (err) {
              Logger.warn('PlaybackSession',
                `system play nowPlaying failed [${PlaybackSession.classifyScrobbleError(err as Error)}]: ${(err as Error).message}`);
            }
          }
        }
      }
    } catch (err) {
      Logger.warn('PlaybackSession', `system play failed: ${(err as Error).message}`);
    } finally {
      PlaybackSession.systemCommandInFlight = false;
    }
  }

  private static async handleSystemPause(): Promise<void> {
    if (PlaybackSession.systemCommandInFlight) {
      return;
    }
    PlaybackSession.systemCommandInFlight = true;
    try {
      const player: media.AVPlayer = await PlaybackSession.ensurePlayer();
      if (player.state === 'playing') {
        await player.pause();
      }
    } catch (err) {
      Logger.warn('PlaybackSession', `system pause failed: ${(err as Error).message}`);
    } finally {
      PlaybackSession.systemCommandInFlight = false;
    }
  }

  private static async handleTrackCompleted(): Promise<void> {
    if (PlaybackSession.handlingCompletion) {
      return;
    }
    PlaybackSession.handlingCompletion = true;
    const completedSong: Song | null = PlaybackSession.getCurrentSong();
    await PlaybackSession.submitCurrentTrackCompletion('completed');
    if (PlaybackSession.queue.length === 0) {
      PlaybackSession.handlingCompletion = false;
      return;
    }
    if (PlaybackSession.currentMode === 'singleLoop') {
      if (completedSong !== null) {
        Logger.debug('PlaybackSession', `single loop restart nowPlaying songId=${completedSong.id}`);
      }
      await PlaybackSession.playCurrentSong(true);
      PlaybackSession.handlingCompletion = false;
      return;
    }
    const nextIndex: number = PlaybackSession.resolveNextIndex(false);
    PlaybackSession.currentIndex = nextIndex;
    await PlaybackSession.playCurrentSong(true);
    PlaybackSession.handlingCompletion = false;
  }

  private static resolveNextIndex(manual: boolean): number {
    const queueSize: number = PlaybackSession.queue.length;
    if (queueSize <= 1) {
      return 0;
    }
    if (PlaybackSession.currentMode === 'random') {
      let candidate: number = Math.floor(Math.random() * queueSize);
      if (candidate === PlaybackSession.currentIndex) {
        candidate = (candidate + 1) % queueSize;
      }
      return candidate;
    }
    if (!manual && PlaybackSession.currentMode === 'singleLoop') {
      return PlaybackSession.currentIndex;
    }
    let nextIndex: number = PlaybackSession.currentIndex + 1;
    if (nextIndex >= queueSize) {
      nextIndex = 0;
    }
    return nextIndex;
  }
}
