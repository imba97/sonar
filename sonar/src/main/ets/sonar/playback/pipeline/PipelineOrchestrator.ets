import { common } from '@kit.AbilityKit';
import { AuthStore, EndpointType } from '../../auth/AuthStore';
import { AuthContext } from '../../network/auth/AuthContext';
import { SongCache } from '../../cache/SongCache';
import { Logger } from '../../common/Logger';
import { HttpTransport } from '../../network/transport/HttpTransport';
import { StreamResource } from '../../network/media/StreamResource';
import { EndpointChangeEvent } from '../../network/routing/EndpointTypes';
import { AudioRenderSink, AudioRenderSinkListener, PlaySinkPhase } from './AudioRenderSink';
import { PipelineMetrics } from './PipelineMetrics';

type PlaybackSource = 'local' | 'remote';

export interface PipelineOrchestratorCallbacks {
  onEnterBuffering(frozenPositionMs: number): void;
  onExitBuffering(): void;
  onPhaseChanged(phase: PlaySinkPhase): void;
  onPositionChanged(positionMs: number): void;
  onDurationChanged(durationMs: number): void;
  onCompleted(): void;
  onError(message: string): void;
  getAuthoritativePositionMs(): number;
  getCurrentPhase(): string;
}

const MAX_REPLAY_RETRIES: number = 3;

/**
 * AVPlayer-only 播放编排：首播 / 切网 / seek 共用 replayAt(HTTP URL)。
 */
export class PipelineOrchestrator implements AudioRenderSinkListener {
  private callbacks: PipelineOrchestratorCallbacks | null = null;
  private readonly audioSink: AudioRenderSink = new AudioRenderSink();
  private activeStreamResource: StreamResource | null = null;
  private migrating: boolean = false;
  private bufferingActive: boolean = false;
  private frozenPositionMs: number = 0;
  private wasPlayingBeforeBuffer: boolean = false;
  private durationMs: number = 0;
  private replayRetryTimerId: number = -1;
  private replayRetryCount: number = 0;
  private lastReplayUrl: string = '';
  private lastReplayLocalPath: string = '';
  private lastReplaySeekMs: number = 0;
  private lastReplayAutoPlay: boolean = false;
  private playbackSource: PlaybackSource = 'remote';
  /** replayAt(seek>0)：等 onReplayReady 再 exitBuffering */
  private awaitReplayReady: boolean = false;

  constructor() {
    this.audioSink.setListener(this);
  }

  setContext(_context: common.UIAbilityContext): void {
  }

  setCallbacks(callbacks: PipelineOrchestratorCallbacks | null): void {
    this.callbacks = callbacks;
  }

  async initialize(): Promise<void> {
    await this.audioSink.initialize();
  }

  async release(): Promise<void> {
    await this.cancel(false);
    await this.audioSink.release();
  }

  getActiveStreamResource(): StreamResource | null {
    return this.activeStreamResource;
  }

  setActiveStreamResource(resource: StreamResource | null): void {
    this.activeStreamResource = resource;
  }

  async startTrack(streamResource: StreamResource, durationMs: number, autoPlay: boolean): Promise<void> {
    await this.cancel(false);
    this.activeStreamResource = streamResource;
    this.durationMs = durationMs;
    await this.replayAtCurrentTarget(0, autoPlay);
    PipelineMetrics.recordTrackStart();
  }

  async cancel(keepStreamResource: boolean = false): Promise<void> {
    this.clearReplayRetry();
    if (this.activeStreamResource !== null && !keepStreamResource) {
      this.activeStreamResource.cancelToken.cancel();
    }
    await this.audioSink.stop();
    this.bufferingActive = false;
    this.awaitReplayReady = false;
    this.migrating = false;
    this.replayRetryCount = 0;
    if (!keepStreamResource) {
      this.activeStreamResource = null;
    }
  }

  async migrateInPlace(frozenPositionMs: number, wasPlaying: boolean): Promise<void> {
    if (this.activeStreamResource === null || this.migrating) {
      return;
    }
    if (this.playbackSource === 'local') {
      return;
    }
    this.migrating = true;
    this.clearReplayRetry();
    this.frozenPositionMs = frozenPositionMs;
    this.wasPlayingBeforeBuffer = wasPlaying;
    this.replayRetryCount = 0;
    this.enterBuffering(frozenPositionMs);
    await this.audioSink.stop();
    try {
      await PipelineOrchestrator.probeStreamEndpoint(this.activeStreamResource.getEndpoint());
    } catch (err) {
      Logger.warn('PipelineOrchestrator', `endpoint probe: ${(err as Error).message}`);
    }
    this.activeStreamResource.timeOffsetMs = 0;
    this.activeStreamResource.byteOffset = 0;
    const url: string = this.resolveStreamUrl();
    await this.replayAt(url, frozenPositionMs, wasPlaying);
    PipelineMetrics.recordMigrate();
    this.migrating = false;
  }

  async onNetworkPathChanged(event: EndpointChangeEvent): Promise<void> {
    if (this.activeStreamResource !== null) {
      this.activeStreamResource.migrate(event.to);
    }
    const frozenMs: number = this.callbacks?.getAuthoritativePositionMs() ?? this.frozenPositionMs;
    const phase: string = this.callbacks?.getCurrentPhase() ?? 'idle';
    const wasPlaying: boolean = phase === 'playing' || this.wasPlayingBeforeBuffer;
    if (this.activeStreamResource === null) {
      return;
    }
    await this.migrateInPlace(frozenMs, wasPlaying);
  }

  async seek(positionMs: number): Promise<void> {
    if (this.activeStreamResource === null) {
      return;
    }
    if (this.audioSink.canSeekInPlace()) {
      await this.audioSink.seek(positionMs);
      this.frozenPositionMs = positionMs;
      PipelineMetrics.recordSeek();
      return;
    }
    const wasPlaying: boolean = this.callbacks?.getCurrentPhase() === 'playing';
    await this.replayAtCurrentTarget(positionMs, wasPlaying);
    PipelineMetrics.recordSeek();
  }

  async play(): Promise<void> {
    const sinkPhase: PlaySinkPhase = this.audioSink.getPhase();
    if (sinkPhase === 'error' || sinkPhase === 'stopped' || sinkPhase === 'idle') {
      await this.resumeAfterError();
      return;
    }
    await this.audioSink.play();
  }

  async resumeAfterError(): Promise<void> {
    if (this.activeStreamResource === null) {
      return;
    }
    const frozenMs: number = this.callbacks?.getAuthoritativePositionMs() ?? this.frozenPositionMs;
    await this.replayAtCurrentTarget(frozenMs > 0 ? frozenMs : this.audioSink.getPositionMs(), true);
  }

  async pause(): Promise<void> {
    await this.audioSink.pause();
  }

  getPositionMs(): number {
    if (this.bufferingActive) {
      return this.frozenPositionMs;
    }
    return this.audioSink.getPositionMs();
  }

  getDurationMs(): number {
    const fromSink: number = this.audioSink.getDurationMs();
    return fromSink > 0 ? fromSink : this.durationMs;
  }

  getPhase(): PlaySinkPhase {
    return this.audioSink.getPhase();
  }

  isBuffering(): boolean {
    return this.bufferingActive;
  }

  isAwaitingReplayReady(): boolean {
    return this.awaitReplayReady;
  }

  private async replayAtCurrentTarget(seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    if (this.activeStreamResource === null) {
      return;
    }
    const localPath: string | null = SongCache.resolveLocalPath(this.activeStreamResource.songId);
    if (localPath !== null) {
      this.playbackSource = 'local';
      await this.replayAtLocal(localPath, seekMs, shouldResumeAfterLoad);
      return;
    }
    this.playbackSource = 'remote';
    const url: string = this.resolveStreamUrl();
    await this.replayAt(url, seekMs, shouldResumeAfterLoad);
  }

  /** open → prepare → play → seek(切网) → 退出 buffering 后按需恢复播放 */
  private async replayAt(url: string, seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    this.lastReplayUrl = url;
    this.lastReplayLocalPath = '';
    this.lastReplaySeekMs = seekMs;
    this.lastReplayAutoPlay = shouldResumeAfterLoad;
    this.awaitReplayReady = seekMs > 0;
    if (seekMs > 0 && !this.bufferingActive) {
      this.wasPlayingBeforeBuffer = shouldResumeAfterLoad;
      this.enterBuffering(seekMs);
    }
    const autoPlayDuringLoad: boolean = seekMs === 0 && shouldResumeAfterLoad && !this.bufferingActive;
    try {
      await this.audioSink.openUrl(url, seekMs, autoPlayDuringLoad);
    } catch (err) {
      Logger.warn('PipelineOrchestrator', `replayAt failed: ${(err as Error).message}`);
      this.callbacks?.onError((err as Error).message);
    }
  }

  private async replayAtLocal(localPath: string, seekMs: number, shouldResumeAfterLoad: boolean): Promise<void> {
    this.lastReplayLocalPath = localPath;
    this.lastReplayUrl = '';
    this.lastReplaySeekMs = seekMs;
    this.lastReplayAutoPlay = shouldResumeAfterLoad;
    this.awaitReplayReady = seekMs > 0;
    if (seekMs > 0 && !this.bufferingActive) {
      this.wasPlayingBeforeBuffer = shouldResumeAfterLoad;
      this.enterBuffering(seekMs);
    }
    const autoPlayDuringLoad: boolean = seekMs === 0 && shouldResumeAfterLoad && !this.bufferingActive;
    try {
      await this.audioSink.openLocalFile(localPath, seekMs, autoPlayDuringLoad);
    } catch (err) {
      const error: Error = err as Error;
      Logger.warn('PipelineOrchestrator', `replayAtLocal failed: ${error.message}`);
      if (this.activeStreamResource !== null &&
        SongCache.shouldInvalidateLocalCache(localPath, error)) {
        await SongCache.removeEntry(this.activeStreamResource.songId);
      }
      this.playbackSource = 'remote';
      const url: string = this.resolveStreamUrl();
      await this.replayAt(url, seekMs, shouldResumeAfterLoad);
    }
  }

  private static async probeStreamEndpoint(endpoint: EndpointType): Promise<void> {
    const creds = AuthStore.getInstance().getCredentials();
    if (creds === null) {
      return;
    }
    const pingUrl: string = AuthContext.buildRestUrl('ping.view', [], creds, endpoint);
    await HttpTransport.probeRest(pingUrl);
  }

  private resolveStreamUrl(): string {
    if (this.activeStreamResource === null) {
      return '';
    }
    return this.activeStreamResource.resolveRequest().url;
  }

  private enterBuffering(frozenPositionMs: number): void {
    this.bufferingActive = true;
    this.frozenPositionMs = frozenPositionMs;
    this.callbacks?.onEnterBuffering(frozenPositionMs);
  }

  private exitBuffering(): void {
    if (!this.bufferingActive) {
      return;
    }
    const shouldResume: boolean = this.wasPlayingBeforeBuffer;
    const targetMs: number = this.frozenPositionMs;
    this.bufferingActive = false;
    this.wasPlayingBeforeBuffer = false;
    this.replayRetryCount = 0;
    this.callbacks?.onExitBuffering();
    void this.resumeAfterBufferingExit(shouldResume, targetMs);
  }

  private async resumeAfterBufferingExit(shouldResume: boolean, targetMs: number): Promise<void> {
    if (targetMs > 0) {
      const currentMs: number = this.audioSink.getPositionMs();
      if (Math.abs(currentMs - targetMs) > 1500) {
        await this.audioSink.seek(targetMs);
      }
    }
    if (shouldResume) {
      await this.audioSink.play();
    }
  }

  private clearReplayRetry(): void {
    if (this.replayRetryTimerId >= 0) {
      clearTimeout(this.replayRetryTimerId);
      this.replayRetryTimerId = -1;
    }
  }

  private scheduleReplayRetry(): void {
    if (!this.bufferingActive ||
      (this.lastReplayUrl.length === 0 && this.lastReplayLocalPath.length === 0)) {
      return;
    }
    if (this.replayRetryCount >= MAX_REPLAY_RETRIES) {
      Logger.warn('PipelineOrchestrator', 'replay retries exhausted');
      this.bufferingActive = false;
      this.callbacks?.onError('replay retries exhausted');
      return;
    }
    this.replayRetryCount++;
    const delayMs: number = 1500 * this.replayRetryCount;
    this.clearReplayRetry();
    this.replayRetryTimerId = setTimeout((): void => {
      this.replayRetryTimerId = -1;
      if (!this.bufferingActive ||
        (this.lastReplayUrl.length === 0 && this.lastReplayLocalPath.length === 0)) {
        return;
      }
      Logger.info('PipelineOrchestrator',
        `retry replay attempt=${this.replayRetryCount} pos=${this.frozenPositionMs}`);
      void this.retryReplayAfterError();
    }, delayMs);
  }

  private retryReplayAfterError(): void {
    if (!this.bufferingActive || this.activeStreamResource === null) {
      return;
    }
    this.activeStreamResource.timeOffsetMs = 0;
    const seekMs: number = this.frozenPositionMs > 0 ? this.frozenPositionMs : this.lastReplaySeekMs;
    void this.replayAtCurrentTarget(seekMs, this.lastReplayAutoPlay);
  }

  onPhaseChanged(phase: PlaySinkPhase): void {
    if (this.bufferingActive && !this.awaitReplayReady) {
      const replayDone: boolean =
        phase === 'playing' ||
        (phase === 'paused' && !this.lastReplayAutoPlay);
      if (replayDone) {
        this.exitBuffering();
      }
    }
    this.callbacks?.onPhaseChanged(phase);
  }

  onReplayReady(positionMs: number): void {
    this.awaitReplayReady = false;
    if (this.activeStreamResource !== null) {
      this.activeStreamResource.timeOffsetMs = 0;
    }
    const reportPos: number =
      this.bufferingActive && this.frozenPositionMs > 0 ? this.frozenPositionMs : positionMs;
    if (this.bufferingActive) {
      this.exitBuffering();
    }
    this.callbacks?.onPositionChanged(reportPos);
  }

  onPositionChanged(positionMs: number): void {
    if (!this.bufferingActive) {
      this.callbacks?.onPositionChanged(positionMs);
    }
  }

  onDurationChanged(durationMs: number): void {
    if (durationMs > 0) {
      this.durationMs = durationMs;
    }
    this.callbacks?.onDurationChanged(durationMs);
  }

  onCompleted(): void {
    this.callbacks?.onCompleted();
  }

  onError(message: string): void {
    Logger.warn('PipelineOrchestrator', message);
    if (this.bufferingActive) {
      this.scheduleReplayRetry();
    }
    this.callbacks?.onError(message);
  }
}
