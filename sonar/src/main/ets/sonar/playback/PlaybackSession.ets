import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { Album, Song, SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { Logger } from '../common/Logger';
import { EndpointChangeEvent } from '../network/routing/EndpointTypes';
import { MediaResourceService } from '../network/media/MediaResourceService';
import { StreamResource } from '../network/media/StreamResource';
import { PlaySinkPhase } from './pipeline/AudioRenderSink';
import { PipelineOrchestrator, PipelineOrchestratorCallbacks } from './pipeline/PipelineOrchestrator';
import { PlaybackPipeline } from './pipeline/PlaybackPipeline';
import { CancelToken } from '../network/transport/CancelToken';
import { PrefetchWorker } from './pipeline/PrefetchWorker';
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

const HEARTBEAT_INTERVAL_MS: number = 15_000;
const MIN_SCROBBLE_TRACK_LENGTH_MS: number = 30_000;
const MAX_SCROBBLE_PROGRESS_THRESHOLD_MS: number = 240_000;

export interface SystemTransportHandler {
  playNext(manual: boolean): Promise<void>;
  playPrevious(): Promise<void>;
  seekTo(positionMs: number): Promise<void>;
  toggle(): Promise<void>;
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

class SessionPipelineCallbacks implements PipelineOrchestratorCallbacks {
  private readonly session: PlaybackSession;

  constructor(session: PlaybackSession) {
    this.session = session;
  }

  onEnterBuffering(frozenPositionMs: number): void {
    this.session.onPipelineEnterBuffering(frozenPositionMs);
  }

  onExitBuffering(): void {
    this.session.onPipelineExitBuffering();
  }

  onPhaseChanged(phase: PlaySinkPhase): void {
    this.session.onPipelinePhase(phase);
  }

  onPositionChanged(positionMs: number): void {
    this.session.onPipelinePosition(positionMs);
  }

  onDurationChanged(durationMs: number): void {
    this.session.onPipelineDuration(durationMs);
  }

  onCompleted(): void {
    void this.session.handleTrackCompleted();
  }

  onError(message: string): void {
    this.session.handlePipelineError(message);
  }

  getAuthoritativePositionMs(): number {
    return this.session.getAuthoritativePositionMs();
  }

  getCurrentPhase(): string {
    return this.session.snapshot.phase;
  }
}

export class PlaybackSession implements PlaybackSwitchHost {
  private static instance: PlaybackSession | null = null;

  private initialized: boolean = false;
  private context: common.UIAbilityContext | null = null;
  private readonly orchestrator: PipelineOrchestrator = new PipelineOrchestrator();
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
  snapshot: PlaybackSnapshot = PlaybackSnapshot.idle();
  private previewTrack: NowPlayingTrack | null = null;
  private transportHandler: SystemTransportHandler | null = null;
  private lastMediaCenterPositionAt: number = 0;
  private activeStreamResource: StreamResource | null = null;
  private isBuffering: boolean = false;
  private frozenPositionMs: number = 0;
  private pipelinePhase: PlaybackPhase = 'idle';
  private prefetchCancelToken: CancelToken | null = null;

  private readonly pipelineCallbacks: PipelineOrchestratorCallbacks = new SessionPipelineCallbacks(this);

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
    this.mediaCenter.setContext(context);
    this.mediaCenter.setCommands(new SessionMediaCenterCommands(this));
    this.orchestrator.setContext(context);
    this.orchestrator.setCallbacks(this.pipelineCallbacks);
    if (this.initialized) {
      return;
    }
    PlaybackStore.init(PlaybackSnapshot.idle());
    await this.orchestrator.initialize();
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
    await this.orchestrator.release();
    await BackgroundPlayback.release();
    await this.mediaCenter.release();
    await CoverCache.releaseAll();
    this.releaseActiveStream();
    this.releaseCover();
    this.queue = [];
    this.currentIndex = -1;
    this.previewTrack = null;
    this.isBuffering = false;
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
    const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
    if (this.pipelinePhase === 'playing' || sinkPhase === 'playing') {
      await this.orchestrator.pause();
      this.pipelinePhase = 'paused';
      this.isBuffering = false;
      this.publishSnapshot('paused', true);
      return;
    }
    if (this.getCurrentSong() === null && this.queue.length > 0) {
      await PlaybackSwitch.commitSwitch(this, true);
      return;
    }
    if (sinkPhase === 'error' || sinkPhase === 'loading' ||
      (this.pipelinePhase === 'loading' && this.getCurrentSong() !== null)) {
      await this.orchestrator.resumeAfterError();
      return;
    }
    await this.orchestrator.play();
    const song: Song | null = this.getCurrentSong();
    if (song !== null) {
      try {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, this.orchestrator.getPositionMs());
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
    this.schedulePrefetchNext();
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
    this.schedulePrefetchNext();
  }

  async seekTo(positionMs: number): Promise<void> {
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      return;
    }
    let maxDurationMs: number = track.durationMs;
    if (maxDurationMs <= 0) {
      maxDurationMs = this.orchestrator.getDurationMs();
    }
    let safe: number = positionMs;
    if (safe < 0) {
      safe = 0;
    }
    if (maxDurationMs > 0 && safe > maxDurationMs) {
      safe = maxDurationMs;
    }
    await this.orchestrator.seek(safe);
    this.frozenPositionMs = safe;
    this.publishSnapshot(this.pipelinePhase, true);
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
    this.isBuffering = false;
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
    this.restoreSnapshotFromPipeline();
  }

  restoreSnapshotFromPipeline(): void {
    const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
    this.pipelinePhase = PlaybackSession.mapSinkPhase(sinkPhase);
    this.isBuffering = this.orchestrator.isBuffering();
    this.publishSnapshot(this.pipelinePhase, true);
  }

  async submitCurrentTrackCompletionOnSwitch(): Promise<void> {
    await this.submitCurrentTrackCompletion('switch');
  }

  async stopEngineAndClearBuffers(): Promise<void> {
    await this.orchestrator.cancel();
    this.releaseActiveStream();
    this.isBuffering = false;
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
      await this.orchestrator.cancel();
      this.releaseCover();
      this.currentIndex = -1;
      this.clearPreview();
      this.isBuffering = false;
      this.pipelinePhase = 'idle';
      this.publishSnapshot('idle', true);
      await BackgroundPlayback.stop();
      PlaybackPipeline.onTrackStopped();
      return;
    }
    this.clearPreview();
    this.isBuffering = false;
    this.frozenPositionMs = 0;
    const track: NowPlayingTrack = buildNowPlayingTrack(song, this.albumCoverFallbackId);
    this.pipelinePhase = 'loading';
    this.publishSnapshot('loading', true);
    this.releaseActiveStream();
    this.activeStreamResource = MediaResourceService.openStream(song.id);
    PlaybackPipeline.onTrackStarted(song.id);
    const durationMs: number = track.durationMs;
    const coverTask: Promise<image.PixelMap | null> = this.ensureCover(track.coverArtId);
    try {
      await this.orchestrator.startTrack(this.activeStreamResource, durationMs, true);
      if (reportStart) {
        await SubsonicClient.getInstance().reportNowPlaying(song.id, 0);
      }
    } catch (err) {
      this.publishSnapshot('error', true);
      Logger.error('PlaybackSession', `play failed: ${(err as Error).message}`);
      return;
    }
    await coverTask;
    this.schedulePrefetchNext();
  }

  private async handleNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    const song: Song | null = this.getCurrentSong();
    if (song === null || this.activeStreamResource === null) {
      return;
    }
    const phase: PlaybackPhase = this.snapshot.phase;
    if (phase !== 'playing' && phase !== 'paused' && phase !== 'loading') {
      return;
    }
    await this.orchestrator.onNetworkPathChanged(event);
  }

  getAuthoritativePositionMs(): number {
    if (this.isBuffering) {
      return this.frozenPositionMs;
    }
    return this.orchestrator.getPositionMs();
  }

  onPipelineEnterBuffering(frozenPositionMs: number): void {
    this.isBuffering = true;
    this.frozenPositionMs = frozenPositionMs;
    if (this.pipelinePhase === 'playing' || this.snapshot.phase === 'playing') {
      this.pipelinePhase = 'paused';
      this.stopHeartbeat();
    }
    this.publishSnapshot(this.pipelinePhase, true);
  }

  onPipelineExitBuffering(): void {
    this.isBuffering = false;
    this.publishSnapshot(this.pipelinePhase, true);
    void this.syncMediaCenter(this.snapshot, true);
  }

  handlePipelineError(message: string): void {
    Logger.warn('PlaybackSession', message);
    if (this.getCurrentSong() !== null &&
      (this.pipelinePhase === 'playing' || this.pipelinePhase === 'paused' || this.isBuffering)) {
      this.isBuffering = true;
      if (this.pipelinePhase === 'playing') {
        this.pipelinePhase = 'paused';
        this.stopHeartbeat();
      }
      this.publishSnapshot(this.pipelinePhase, true);
      void this.syncMediaCenter(this.snapshot, true);
      return;
    }
    this.isBuffering = false;
    this.publishSnapshot('error');
  }

  onPipelinePhase(phase: PlaySinkPhase): void {
    if (phase === 'error') {
      this.handlePipelineError('player error');
      return;
    }
    if (this.isBuffering && (this.pipelinePhase === 'playing' || phase === 'loading' ||
      phase === 'stopped' || phase === 'idle')) {
      return;
    }
    if (this.pipelinePhase === 'playing' && phase === 'loading') {
      return;
    }
    this.pipelinePhase = PlaybackSession.mapSinkPhase(phase);
    if (this.pipelinePhase === 'playing') {
      this.startHeartbeat();
    } else if (this.pipelinePhase === 'paused' || this.pipelinePhase === 'error' ||
      this.pipelinePhase === 'idle') {
      this.stopHeartbeat();
    }
    this.publishSnapshot(this.pipelinePhase, true);
    void this.syncMediaCenter(this.snapshot, true);
    const track: NowPlayingTrack | null = this.snapshot.track;
    if (track === null) {
      void BackgroundPlayback.stop();
      return;
    }
    if (this.pipelinePhase === 'playing') {
      void BackgroundPlayback.start(track.title, track.artist, true);
      return;
    }
    if (this.pipelinePhase === 'paused' || this.pipelinePhase === 'idle' || this.pipelinePhase === 'error') {
      void BackgroundPlayback.update(track.title, track.artist, false);
    }
  }

  onPipelinePosition(_positionMs: number): void {
    if (this.previewTrack !== null || this.isBuffering) {
      return;
    }
    this.publishSnapshot(this.pipelinePhase, false);
    const now: number = Date.now();
    if (now - this.lastMediaCenterPositionAt < 1000) {
      return;
    }
    this.lastMediaCenterPositionAt = now;
    void this.mediaCenter.syncPlaybackState(this.snapshot);
  }

  onPipelineDuration(durationMs: number): void {
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
      this.coverRevision,
      this.isBuffering
    );
    PlaybackStore.publish(this.snapshot);
    if (durationMs > 0) {
      void this.syncMediaCenter(this.snapshot, true);
    }
  }

  private static mapSinkPhase(phase: PlaySinkPhase): PlaybackPhase {
    if (phase === 'loading') {
      return 'loading';
    }
    if (phase === 'playing') {
      return 'playing';
    }
    if (phase === 'paused') {
      return 'paused';
    }
    if (phase === 'error') {
      return 'error';
    }
    return 'idle';
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
        const durationMs: number = this.orchestrator.getDurationMs();
        if (durationMs > 0) {
          track = new NowPlayingTrack(
            track.id,
            track.title,
            track.artist,
            track.album,
            track.coverArtId,
            durationMs
          );
        }
      }
      if (this.isBuffering) {
        positionMs = this.frozenPositionMs;
      } else {
        positionMs = this.orchestrator.getPositionMs();
      }
    }

    this.snapshot = new PlaybackSnapshot(
      track,
      snapshotPhase,
      positionMs,
      this.currentMode,
      showMiniPlayer,
      this.coverRevision,
      this.isBuffering
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
      const sinkPhase: PlaySinkPhase = this.orchestrator.getPhase();
      if (sinkPhase === 'playing') {
        return;
      }
      if (this.getCurrentSong() === null && this.queue.length > 0) {
        await PlaybackSwitch.commitSwitch(this, true);
        return;
      }
      if (sinkPhase === 'error' || sinkPhase === 'loading' ||
        (this.pipelinePhase === 'loading' && this.getCurrentSong() !== null)) {
        await this.orchestrator.resumeAfterError();
        return;
      }
      await this.orchestrator.play();
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
      if (this.orchestrator.getPhase() === 'playing') {
        await this.orchestrator.pause();
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
    this.schedulePrefetchNext();
    this.handlingCompletion = false;
  }

  private schedulePrefetchNext(): void {
    if (this.prefetchCancelToken !== null) {
      this.prefetchCancelToken.cancel();
      this.prefetchCancelToken = null;
    }
    if (this.queue.length === 0 || this.currentIndex < 0) {
      return;
    }
    const nextIndex: number = resolveNextIndex(this.queue, this.currentIndex, this.currentMode, false);
    const nextSong: Song = this.queue[nextIndex];
    this.prefetchCancelToken = PrefetchWorker.prefetchNextSong(nextSong.id);
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
      await SubsonicClient.getInstance().reportNowPlaying(song.id, this.getAuthoritativePositionMs());
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
    const durationMs: number = song.duration > 0 ? song.duration * 1000 : this.orchestrator.getDurationMs();
    let playedMs: number = this.getAuthoritativePositionMs();
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
