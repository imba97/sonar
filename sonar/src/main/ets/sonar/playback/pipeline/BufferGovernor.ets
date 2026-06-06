import {
  estimatePlayableMsFromCompressedBytes,
  PCM_BYTES_PER_SECOND,
  PLAYBACK_BUFFER_SECONDS,
  REBUFFER_LOW_WATERMARK_SECONDS,
  TARGET_BUFFER_SECONDS
} from './PlaybackBufferPolicy';

export type GovernorState = 'normal' | 'buffering';

export interface BufferGovernorListener {
  onEnterBuffering(frozenPositionMs: number): void;
  onExitBuffering(): void;
  onReadyToPlay(): void;
}

export class BufferGovernor {
  private state: GovernorState = 'normal';
  private compressedBytes: number = 0;
  private pcmBytes: number = 0;
  private contentLength: number = 0;
  private durationMs: number = 0;
  private fetchActive: boolean = false;
  private playStarted: boolean = false;
  private listener: BufferGovernorListener | null = null;
  private forcedBuffering: boolean = false;
  private frozenPositionMs: number = 0;

  setListener(listener: BufferGovernorListener | null): void {
    this.listener = listener;
  }

  reset(): void {
    this.state = 'normal';
    this.compressedBytes = 0;
    this.pcmBytes = 0;
    this.contentLength = 0;
    this.durationMs = 0;
    this.fetchActive = false;
    this.playStarted = false;
    this.forcedBuffering = false;
    this.frozenPositionMs = 0;
  }

  setDurationMs(durationMs: number): void {
    if (durationMs > 0) {
      this.durationMs = durationMs;
    }
  }

  setFetchActive(active: boolean): void {
    this.fetchActive = active;
  }

  markPlayStarted(): void {
    this.playStarted = true;
  }

  /** 切网 migrate：强制进入 buffering，冻结进度 */
  forceEnterBuffering(frozenPositionMs: number): void {
    this.forcedBuffering = true;
    this.frozenPositionMs = frozenPositionMs;
    if (this.state !== 'buffering') {
      this.state = 'buffering';
      this.listener?.onEnterBuffering(frozenPositionMs);
    }
  }

  onFetchProgress(downloadedBytes: number, contentLength?: number): void {
    this.compressedBytes = downloadedBytes;
    if (contentLength !== undefined && contentLength > 0) {
      this.contentLength = contentLength;
    }
    this.evaluate();
  }

  onPcmAvailable(pcmBytes: number): void {
    this.pcmBytes = pcmBytes;
    this.evaluate();
  }

  getEstimatedPlayableMs(): number {
    if (this.contentLength > 0 && this.durationMs > 0 && this.compressedBytes > 0) {
      return Math.floor((this.compressedBytes / this.contentLength) * this.durationMs);
    }
    const fromCompressed: number = estimatePlayableMsFromCompressedBytes(this.compressedBytes);
    const fromPcm: number = Math.floor((this.pcmBytes / PCM_BYTES_PER_SECOND) * 1000);
    return Math.max(fromCompressed, fromPcm);
  }

  canStartPlayback(): boolean {
    return this.getEstimatedPlayableMs() >= TARGET_BUFFER_SECONDS * 1000;
  }

  isBuffering(): boolean {
    return this.state === 'buffering';
  }

  private evaluate(): void {
    const playableMs: number = this.getEstimatedPlayableMs();
    if (!this.playStarted) {
      if (this.canStartPlayback()) {
        this.listener?.onReadyToPlay();
      }
      return;
    }
    if (this.forcedBuffering) {
      if (playableMs >= TARGET_BUFFER_SECONDS * 1000) {
        this.forcedBuffering = false;
        this.exitBuffering();
      }
      return;
    }
    const lowMs: number = REBUFFER_LOW_WATERMARK_SECONDS * 1000;
    const targetMs: number = PLAYBACK_BUFFER_SECONDS * 1000;
    if (this.state === 'normal' && playableMs < lowMs && this.fetchActive) {
      this.state = 'buffering';
      this.listener?.onEnterBuffering(this.frozenPositionMs);
      return;
    }
    if (this.state === 'buffering' && playableMs >= targetMs) {
      this.exitBuffering();
    }
  }

  private exitBuffering(): void {
    if (this.state === 'buffering') {
      this.state = 'normal';
      this.listener?.onExitBuffering();
    }
  }
}
