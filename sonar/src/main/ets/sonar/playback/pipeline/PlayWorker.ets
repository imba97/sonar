import { Logger } from '../../common/Logger';
import { AudioRenderSink, AudioRenderSinkListener, PlaySinkPhase } from './AudioRenderSink';
import { BufferGovernor } from './BufferGovernor';

export interface PlayWorkerCallbacks {
  onPhaseChanged?: (phase: PlaySinkPhase) => void;
  onPositionChanged?: (positionMs: number) => void;
  onDurationChanged?: (durationMs: number) => void;
  onCompleted?: () => void;
  onError?: (message: string) => void;
}

/**
 * 播放 Worker：Governor 水位达标后驱动 AudioRenderSink 出声。
 */
export class PlayWorker implements AudioRenderSinkListener {
  private readonly sink: AudioRenderSink;
  private governor: BufferGovernor | null = null;
  private callbacks: PlayWorkerCallbacks | null = null;
  private pendingUrl: string = '';
  private pendingAutoPlay: boolean = false;
  private pendingSeekMs: number = 0;
  private waitingForBuffer: boolean = false;

  constructor(sink: AudioRenderSink) {
    this.sink = sink;
    this.sink.setListener(this);
  }

  setGovernor(governor: BufferGovernor): void {
    this.governor = governor;
  }

  setCallbacks(callbacks: PlayWorkerCallbacks | null): void {
    this.callbacks = callbacks;
  }

  async initialize(): Promise<void> {
    await this.sink.initialize();
  }

  async release(): Promise<void> {
    this.waitingForBuffer = false;
    this.pendingUrl = '';
    await this.sink.release();
  }

  /** 新歌：等 ≥10s 缓冲后再 open */
  scheduleStart(url: string, autoPlay: boolean, startSeekMs: number = 0): void {
    this.pendingUrl = url;
    this.pendingAutoPlay = autoPlay;
    this.pendingSeekMs = startSeekMs;
    this.waitingForBuffer = true;
    if (this.governor !== null && this.governor.canStartPlayback()) {
      void this.tryStartPending();
    }
  }

  /** migrate：Governor 强制 buffering 后重启出声 */
  scheduleMigrate(url: string, seekMs: number, wasPlaying: boolean): void {
    this.pendingUrl = url;
    this.pendingAutoPlay = wasPlaying;
    this.pendingSeekMs = seekMs;
    this.waitingForBuffer = true;
    if (this.governor !== null && this.governor.canStartPlayback()) {
      void this.tryStartPending();
    }
  }

  onGovernorReadyToPlay(): void {
    if (this.waitingForBuffer) {
      void this.tryStartPending();
    }
  }

  async play(): Promise<void> {
    await this.sink.play();
  }

  async pause(): Promise<void> {
    await this.sink.pause();
  }

  async stop(): Promise<void> {
    this.waitingForBuffer = false;
    this.pendingUrl = '';
    await this.sink.stop();
  }

  async seek(positionMs: number): Promise<void> {
    await this.sink.seek(positionMs);
  }

  getPositionMs(): number {
    return this.sink.getPositionMs();
  }

  getDurationMs(): number {
    return this.sink.getDurationMs();
  }

  getPhase(): PlaySinkPhase {
    return this.sink.getPhase();
  }

  private async tryStartPending(): Promise<void> {
    if (!this.waitingForBuffer || this.pendingUrl.length === 0) {
      return;
    }
    if (this.governor !== null && !this.governor.canStartPlayback()) {
      return;
    }
    this.waitingForBuffer = false;
    const url: string = this.pendingUrl;
    const autoPlay: boolean = this.pendingAutoPlay;
    const seekMs: number = this.pendingSeekMs;
    this.pendingUrl = '';
    this.pendingSeekMs = 0;
    try {
      if (seekMs > 0 && this.sink.getPhase() !== 'idle') {
        await this.sink.migrateStream(url, seekMs, autoPlay);
      } else {
        await this.sink.openStream(url, autoPlay, seekMs);
      }
      this.governor?.markPlayStarted();
    } catch (err) {
      Logger.warn('PlayWorker', `start failed: ${(err as Error).message}`);
      this.callbacks?.onError?.((err as Error).message);
    }
  }

  onPhaseChanged(phase: PlaySinkPhase): void {
    this.callbacks?.onPhaseChanged?.(phase);
  }

  onPositionChanged(positionMs: number): void {
    this.callbacks?.onPositionChanged?.(positionMs);
  }

  onDurationChanged(durationMs: number): void {
    this.callbacks?.onDurationChanged?.(durationMs);
  }

  onCompleted(): void {
    this.callbacks?.onCompleted?.();
  }

  onError(message: string): void {
    this.callbacks?.onError?.(message);
  }
}
