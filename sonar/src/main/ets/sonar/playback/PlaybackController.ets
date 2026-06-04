import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { Song, SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';
import { BackgroundPlayback } from './BackgroundPlayback';
import { CoverCache } from './CoverCache';
import { MediaCenter, MediaCenterCommands } from './MediaCenter';
import {
  buildNowPlayingTrack,
  NowPlayingTrack,
  PlaybackMode,
  PlaybackPhase,
  PlaybackSnapshot
} from './PlaybackSnapshot';
import { PlaybackStore } from './PlaybackStore';
import { EnginePhase, PcmPlaybackEngine, PcmPlaybackEngineListener } from './PcmPlaybackEngine';
import { PcmRingBuffer } from './PcmRingBuffer';
import { StreamDecoder } from './StreamDecoder';

const HEARTBEAT_INTERVAL_MS: number = 15_000;
const MIN_SCROBBLE_TRACK_LENGTH_MS: number = 30_000;
const MAX_SCROBBLE_PROGRESS_THRESHOLD_MS: number = 240_000;
const RING_CAPACITY_BYTES: number = 1024 * 1024 * 2;

class PcmEngineListenerAdapter implements PcmPlaybackEngineListener {
  onPhaseChanged(phase: EnginePhase): void {
    PlaybackController.onEnginePhase(phase);
  }

  onPositionChanged(positionMs: number): void {
    PlaybackController.onEnginePosition(positionMs);
  }

  onDurationChanged(durationMs: number): void {
    PlaybackController.onEngineDuration(durationMs);
  }

  onCompleted(): void {
    void PlaybackController.handleTrackCompleted();
  }

  onError(message: string): void {
    Logger.warn('PlaybackController', message);
    PlaybackController.publishSnapshot('error');
  }
}

class MediaCenterCommandsAdapter implements MediaCenterCommands {
  async onPlay(): Promise<void> {
    await PlaybackController.handleSystemPlay();
  }

  async onPause(): Promise<void> {
    await PlaybackController.handleSystemPause();
  }

  async onNext(): Promise<void> {
    await PlaybackController.playNext(true);
  }

  async onPrevious(): Promise<void> {
    await PlaybackController.playPrevious();
  }

  async onSeek(positionMs: number): Promise<void> {
    await PlaybackController.seekTo(positionMs);
  }
}

export class PlaybackController {
  private static initialized: boolean = false;
  private static context: common.UIAbilityContext | null = null;
  private static engine: PcmPlaybackEngine = new PcmPlaybackEngine();
  private static decoder: StreamDecoder = new StreamDecoder();
  private static ring: PcmRingBuffer = new PcmRingBuffer(RING_CAPACITY_BYTES);
  private static mediaCenter: MediaCenter = new MediaCenter();
  private static queue: Song[] = [];
  private static currentIndex: number = -1;
  private static currentMode: PlaybackMode = 'listLoop';
  private static bottomDockSwapped: boolean = false;
  private static coverRevision: number = 0;
  private static currentCover: image.PixelMap | null = null;
  private static currentCoverId: string = '';
  private static heartbeatTimerId: number = -1;
  private static handlingCompletion: boolean = false;
  private static systemCommandInFlight: boolean = false;
  private static albumCoverFallbackId: string = '';
  private static snapshot: PlaybackSnapshot = PlaybackSnapshot.idle();

  private static readonly engineListener: PcmPlaybackEngineListener = new PcmEngineListenerAdapter();
  private static readonly mediaCommands: MediaCenterCommands = new MediaCenterCommandsAdapter();

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    PlaybackController.context = context;
    CoverCache.setContext(context);
    BackgroundPlayback.setContext(context);
    PlaybackController.decoder.setContext(context);
    PlaybackController.mediaCenter.setContext(context);
    PlaybackController.mediaCenter.setCommands(PlaybackController.mediaCommands);
    if (PlaybackController.initialized) {
      return;
    }
    PlaybackStore.init(PlaybackSnapshot.idle());
    PlaybackController.engine.setListener(PlaybackController.engineListener);
    await PlaybackController.engine.initialize();
    PlaybackController.initialized = true;
  }

  static setContext(context: common.UIAbilityContext): void {
    void PlaybackController.initialize(context);
  }

  static async release(): Promise<void> {
    PlaybackController.stopHeartbeat();
    PlaybackController.systemCommandInFlight = false;
    await PlaybackController.submitCurrentTrackCompletion('release');
    await PlaybackController.engine.stop();
    await PlaybackController.engine.release();
    PlaybackController.ring.clear();
    PlaybackController.decoder.reset();
    await BackgroundPlayback.release();
    await PlaybackController.mediaCenter.release();
    await CoverCache.releaseAll();
    PlaybackController.releaseCover();
    PlaybackController.queue = [];
    PlaybackController.currentIndex = -1;
    PlaybackController.initialized = false;
    PlaybackController.snapshot = PlaybackSnapshot.idle();
    PlaybackStore.publish(PlaybackController.snapshot);
  }

  static getCurrentMode(): PlaybackMode {
    return PlaybackController.currentMode;
  }

  static togglePlaybackMode(): PlaybackMode {
    if (PlaybackController.currentMode === 'listLoop') {
      PlaybackController.currentMode = 'singleLoop';
    } else if (PlaybackController.currentMode === 'singleLoop') {
      PlaybackController.currentMode = 'random';
    } else {
      PlaybackController.currentMode = 'listLoop';
    }
    PlaybackController.publishSnapshot(PlaybackController.snapshot.phase, true);
    return PlaybackController.currentMode;
  }

  static async playQueue(songs: Song[], index: number, albumCoverArtId?: string): Promise<void> {
    if (songs.length === 0) {
      return;
    }
    PlaybackController.albumCoverFallbackId = albumCoverArtId ?? '';
    await PlaybackController.submitCurrentTrackCompletionOnSwitch();
    const safeIndex: number = index >= 0 && index < songs.length ? index : 0;
    PlaybackController.queue = songs.map((item: Song) => item);
    PlaybackController.currentIndex = safeIndex;
    await PlaybackController.playCurrentSong(true);
  }

  /** @deprecated 使用 playQueue */
  static async playFromList(songs: Song[], index: number): Promise<void> {
    await PlaybackController.playQueue(songs, index);
  }

  static async enqueueNext(song: Song): Promise<void> {
    if (PlaybackController.queue.length === 0 || PlaybackController.currentIndex < 0) {
      PlaybackController.queue = [song];
      PlaybackController.currentIndex = 0;
      await PlaybackController.playCurrentSong(true);
      return;
    }
    const nextInsertIndex: number = PlaybackController.currentIndex + 1;
    const before: Song[] = PlaybackController.queue.slice(0, nextInsertIndex);
    const after: Song[] = PlaybackController.queue.slice(nextInsertIndex);
    PlaybackController.queue = [...before, song, ...after];
  }

  static async toggle(): Promise<void> {
    const phase: EnginePhase = PlaybackController.engine.getPhase();
    if (phase === 'playing') {
      await PlaybackController.engine.pause();
      return;
    }
    if (PlaybackController.getCurrentSong() === null && PlaybackController.queue.length > 0) {
      await PlaybackController.playCurrentSong(true);
      return;
    }
    await PlaybackController.engine.play();
    const song: Song | null = PlaybackController.getCurrentSong();
    if (song !== null) {
      try {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, PlaybackController.engine.getPositionMs());
      } catch (err) {
        Logger.warn('PlaybackController',
          `resume nowPlaying failed: ${PlaybackController.classifyScrobbleError(err as Error)}`);
      }
    }
  }

  /** @deprecated 使用 toggle */
  static async togglePlayPause(): Promise<void> {
    await PlaybackController.toggle();
  }

  static async playNext(manual: boolean = true): Promise<void> {
    if (PlaybackController.queue.length === 0) {
      return;
    }
    await PlaybackController.submitCurrentTrackCompletionOnSwitch();
    PlaybackController.currentIndex = PlaybackController.resolveNextIndex(manual);
    await PlaybackController.playCurrentSong(true);
  }

  static async playPrevious(): Promise<void> {
    if (PlaybackController.queue.length === 0) {
      return;
    }
    await PlaybackController.submitCurrentTrackCompletionOnSwitch();
    const queueSize: number = PlaybackController.queue.length;
    if (queueSize === 1) {
      PlaybackController.currentIndex = 0;
      await PlaybackController.playCurrentSong(true);
      return;
    }
    let prevIndex: number = PlaybackController.currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = queueSize - 1;
    }
    PlaybackController.currentIndex = prevIndex;
    await PlaybackController.playCurrentSong(true);
  }

  static async seekTo(positionMs: number): Promise<void> {
    const track: NowPlayingTrack | null = PlaybackController.snapshot.track;
    if (track === null || track.durationMs <= 0) {
      return;
    }
    let safe: number = positionMs;
    if (safe < 0) {
      safe = 0;
    }
    if (safe > track.durationMs) {
      safe = track.durationMs;
    }
    await PlaybackController.engine.seek(safe);
    PlaybackController.publishSnapshot(PlaybackController.snapshot.phase, true);
  }

  static setBottomDockSwapped(swapped: boolean): void {
    PlaybackController.bottomDockSwapped = swapped;
    PlaybackController.publishSnapshot(PlaybackController.snapshot.phase, true);
  }

  private static async playCurrentSong(reportStart: boolean): Promise<void> {
    const song: Song | null = PlaybackController.getCurrentSong();
    if (song === null) {
      await PlaybackController.engine.stop();
      PlaybackController.releaseCover();
      PlaybackController.currentIndex = -1;
      PlaybackController.publishSnapshot('idle', true);
      await BackgroundPlayback.stop();
      return;
    }
    await PlaybackController.engine.stop();
    PlaybackController.ring.clear();
    PlaybackController.decoder.reset();
    const track: NowPlayingTrack =
      buildNowPlayingTrack(song, PlaybackController.albumCoverFallbackId);
    PlaybackController.publishSnapshot('loading', true);
    const streamUrl: string = SubsonicClient.getInstance().getStreamUrl(song.id);
    const coverTask: Promise<image.PixelMap | null> = PlaybackController.ensureCover(track.coverArtId);
    try {
      await PlaybackController.engine.loadStreamUrl(streamUrl, true);
      if (reportStart) {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, 0);
      }
    } catch (err) {
      PlaybackController.publishSnapshot('error', true);
      Logger.error('PlaybackController', `play failed: ${(err as Error).message}`);
      return;
    }
    await coverTask;
    PlaybackController.publishSnapshot('loading', true);
  }

  static onEnginePhase(phase: EnginePhase): void {
    let playbackPhase: PlaybackPhase = 'idle';
    if (phase === 'loading') {
      playbackPhase = 'loading';
    } else if (phase === 'playing') {
      playbackPhase = 'playing';
      PlaybackController.startHeartbeat();
    } else if (phase === 'paused') {
      playbackPhase = 'paused';
      PlaybackController.stopHeartbeat();
    } else if (phase === 'error') {
      playbackPhase = 'error';
      PlaybackController.stopHeartbeat();
    } else {
      playbackPhase = 'idle';
      PlaybackController.stopHeartbeat();
    }
    PlaybackController.publishSnapshot(playbackPhase, true);
    void PlaybackController.syncMediaCenter(PlaybackController.snapshot, true);
    const track: NowPlayingTrack | null = PlaybackController.snapshot.track;
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

  static onEnginePosition(_positionMs: number): void {
    PlaybackController.publishSnapshot(PlaybackController.snapshot.phase, false);
    void PlaybackController.syncMediaCenter(PlaybackController.snapshot, false);
  }

  static onEngineDuration(durationMs: number): void {
    const track: NowPlayingTrack | null = PlaybackController.snapshot.track;
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
    PlaybackController.snapshot = new PlaybackSnapshot(
      updated,
      PlaybackController.snapshot.phase,
      PlaybackController.snapshot.positionMs,
      PlaybackController.currentMode,
      PlaybackController.currentIndex >= 0,
      PlaybackController.bottomDockSwapped,
      PlaybackController.coverRevision
    );
    PlaybackStore.publish(PlaybackController.snapshot);
  }

  static publishSnapshot(phase: PlaybackPhase, forceMedia: boolean = false): void {
    const song: Song | null = PlaybackController.getCurrentSong();
    let track: NowPlayingTrack | null = null;
    if (song !== null) {
      track = buildNowPlayingTrack(song, PlaybackController.albumCoverFallbackId);
      if (PlaybackController.engine.getDurationMs() > 0) {
        track = new NowPlayingTrack(
          track.id,
          track.title,
          track.artist,
          track.album,
          track.coverArtId,
          PlaybackController.engine.getDurationMs()
        );
      }
    }
    const positionMs: number = PlaybackController.engine.getPositionMs();
    PlaybackController.snapshot = new PlaybackSnapshot(
      track,
      phase,
      positionMs,
      PlaybackController.currentMode,
      PlaybackController.currentIndex >= 0,
      PlaybackController.bottomDockSwapped,
      PlaybackController.coverRevision
    );
    PlaybackStore.publish(PlaybackController.snapshot);
    if (forceMedia) {
      void PlaybackController.syncMediaCenter(PlaybackController.snapshot, true);
    }
  }

  private static async syncMediaCenter(snapshot: PlaybackSnapshot, force: boolean): Promise<void> {
    let cover: image.PixelMap | null = null;
    if (snapshot.track !== null && snapshot.track.coverArtId.length > 0) {
      cover = CoverCache.getDisplaySource(snapshot.track.coverArtId).pixelMap;
      if (cover === null) {
        cover = await CoverCache.load(snapshot.track.coverArtId);
        if (cover !== null) {
          PlaybackController.coverRevision = CoverCache.getRevision();
        }
      }
      PlaybackController.currentCover = cover;
      PlaybackController.currentCoverId = snapshot.track.coverArtId;
    } else {
      PlaybackController.releaseCover();
    }
    await PlaybackController.mediaCenter.apply(snapshot, cover);
  }

  private static async ensureCover(coverArtId: string): Promise<image.PixelMap | null> {
    if (coverArtId.length === 0) {
      return null;
    }
    const existing: image.PixelMap | null = CoverCache.getDisplaySource(coverArtId).pixelMap;
    if (existing !== null) {
      PlaybackController.coverRevision = CoverCache.getRevision();
      return existing;
    }
    const loaded: image.PixelMap | null = await CoverCache.load(coverArtId);
    if (loaded !== null) {
      PlaybackController.coverRevision = CoverCache.getRevision();
      PlaybackController.publishSnapshot(PlaybackController.snapshot.phase, true);
    }
    return loaded;
  }

  private static releaseCover(): void {
    PlaybackController.currentCover = null;
    PlaybackController.currentCoverId = '';
  }

  static async handleSystemPlay(): Promise<void> {
    if (PlaybackController.systemCommandInFlight) {
      return;
    }
    PlaybackController.systemCommandInFlight = true;
    try {
      if (PlaybackController.engine.getPhase() !== 'playing') {
        if (PlaybackController.getCurrentSong() === null && PlaybackController.queue.length > 0) {
          await PlaybackController.playCurrentSong(true);
        } else {
          await PlaybackController.engine.play();
        }
      }
    } finally {
      PlaybackController.systemCommandInFlight = false;
    }
  }

  static async handleSystemPause(): Promise<void> {
    if (PlaybackController.systemCommandInFlight) {
      return;
    }
    PlaybackController.systemCommandInFlight = true;
    try {
      if (PlaybackController.engine.getPhase() === 'playing') {
        await PlaybackController.engine.pause();
      }
    } finally {
      PlaybackController.systemCommandInFlight = false;
    }
  }

  static async handleTrackCompleted(): Promise<void> {
    if (PlaybackController.handlingCompletion) {
      return;
    }
    PlaybackController.handlingCompletion = true;
    await PlaybackController.submitCurrentTrackCompletion('completed');
    if (PlaybackController.queue.length === 0) {
      PlaybackController.handlingCompletion = false;
      return;
    }
    if (PlaybackController.currentMode === 'singleLoop') {
      await PlaybackController.playCurrentSong(true);
      PlaybackController.handlingCompletion = false;
      return;
    }
    PlaybackController.currentIndex = PlaybackController.resolveNextIndex(false);
    await PlaybackController.playCurrentSong(true);
    PlaybackController.handlingCompletion = false;
  }

  private static getCurrentSong(): Song | null {
    if (PlaybackController.currentIndex < 0 || PlaybackController.currentIndex >= PlaybackController.queue.length) {
      return null;
    }
    return PlaybackController.queue[PlaybackController.currentIndex];
  }

  private static resolveNextIndex(manual: boolean): number {
    const queueSize: number = PlaybackController.queue.length;
    if (queueSize <= 1) {
      return 0;
    }
    if (PlaybackController.currentMode === 'random') {
      let candidate: number = Math.floor(Math.random() * queueSize);
      if (candidate === PlaybackController.currentIndex) {
        candidate = (candidate + 1) % queueSize;
      }
      return candidate;
    }
    if (!manual && PlaybackController.currentMode === 'singleLoop') {
      return PlaybackController.currentIndex;
    }
    let nextIndex: number = PlaybackController.currentIndex + 1;
    if (nextIndex >= queueSize) {
      nextIndex = 0;
    }
    return nextIndex;
  }

  private static startHeartbeat(): void {
    PlaybackController.stopHeartbeat();
    PlaybackController.heartbeatTimerId = setInterval(() => {
      void PlaybackController.reportHeartbeat();
    }, HEARTBEAT_INTERVAL_MS);
  }

  private static stopHeartbeat(): void {
    if (PlaybackController.heartbeatTimerId >= 0) {
      clearInterval(PlaybackController.heartbeatTimerId);
      PlaybackController.heartbeatTimerId = -1;
    }
  }

  private static async reportHeartbeat(): Promise<void> {
    const song: Song | null = PlaybackController.getCurrentSong();
    if (song === null || PlaybackController.snapshot.phase !== 'playing') {
      return;
    }
    try {
      await SubsonicClient.getInstance().reportNowPlaying(song.id, PlaybackController.engine.getPositionMs());
    } catch (err) {
      Logger.warn('PlaybackController',
        `heartbeat failed: ${PlaybackController.classifyScrobbleError(err as Error)}`);
    }
  }

  private static classifyScrobbleError(err: Error): string {
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

  private static async submitCurrentTrackCompletion(reason: string): Promise<void> {
    const song: Song | null = PlaybackController.getCurrentSong();
    if (song === null) {
      return;
    }
    const durationMs: number = song.duration > 0 ? song.duration * 1000 : PlaybackController.engine.getDurationMs();
    let playedMs: number = PlaybackController.engine.getPositionMs();
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
      Logger.debug('PlaybackController', `scrobble ok reason=${reason} id=${song.id}`);
    } catch (err) {
      Logger.warn('PlaybackController', `scrobble failed: ${(err as Error).message}`);
    }
  }

  private static async submitCurrentTrackCompletionOnSwitch(): Promise<void> {
    await PlaybackController.submitCurrentTrackCompletion('switch');
  }
}
