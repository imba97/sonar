import { media } from '@kit.MediaKit';
import { Logger } from '../../common/Logger';

export type PlaySinkPhase = 'idle' | 'loading' | 'playing' | 'paused' | 'stopped' | 'error';

export interface AudioRenderSinkListener {
  onPhaseChanged(phase: PlaySinkPhase): void;
  onPositionChanged(positionMs: number): void;
  onDurationChanged(durationMs: number): void;
  onCompleted(): void;
  onError(message: string): void;
}

/**
 * 播放输出：当前经 AVPlayer 解码出声；PCM 环就绪后可切 AudioRenderer writeData。
 */
export class AudioRenderSink {
  private listener: AudioRenderSinkListener | null = null;
  private player: media.AVPlayer | null = null;
  private phase: PlaySinkPhase = 'idle';
  private pendingAutoPlay: boolean = false;
  private pendingSeekMs: number = 0;
  private migratePending: boolean = false;
  private positionMs: number = 0;
  private durationMs: number = 0;

  setListener(listener: AudioRenderSinkListener | null): void {
    this.listener = listener;
  }

  getPhase(): PlaySinkPhase {
    return this.phase;
  }

  getPositionMs(): number {
    return this.positionMs;
  }

  getDurationMs(): number {
    return this.durationMs;
  }

  async initialize(): Promise<void> {
    await this.ensurePlayer();
  }

  async release(): Promise<void> {
    this.pendingAutoPlay = false;
    this.pendingSeekMs = 0;
    this.migratePending = false;
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (err) {
        Logger.warn('AudioRenderSink', `release failed: ${(err as Error).message}`);
      }
      this.player = null;
    }
    this.setPhase('idle');
    this.positionMs = 0;
    this.durationMs = 0;
  }

  async openStream(url: string, autoPlay: boolean, startSeekMs: number = 0): Promise<void> {
    const player: media.AVPlayer = await this.ensurePlayer();
    this.pendingAutoPlay = autoPlay;
    this.pendingSeekMs = startSeekMs;
    this.migratePending = false;
    this.setPhase('loading');
    try {
      await player.reset();
    } catch (err) {
      Logger.warn('AudioRenderSink', `reset failed: ${(err as Error).message}`);
    }
    player.url = url;
  }

  /** 切网续播：换 URL 后在 prepared 态 seek 至冻结点，禁止 UI 归零 */
  async migrateStream(url: string, seekMs: number, wasPlaying: boolean): Promise<void> {
    this.pendingAutoPlay = wasPlaying;
    this.pendingSeekMs = seekMs;
    this.migratePending = true;
    const player: media.AVPlayer = await this.ensurePlayer();
    try {
      if (player.state === 'playing') {
        await player.pause();
      }
    } catch (_err) {
    }
    try {
      await player.reset();
    } catch (err) {
      Logger.warn('AudioRenderSink', `migrate reset failed: ${(err as Error).message}`);
    }
    player.url = url;
  }

  async play(): Promise<void> {
    const player: media.AVPlayer = await this.ensurePlayer();
    if (player.state === 'playing') {
      return;
    }
    try {
      await player.play();
    } catch (err) {
      this.emitError(`play failed: ${(err as Error).message}`);
    }
  }

  async pause(): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null || player.state !== 'playing') {
      return;
    }
    try {
      await player.pause();
    } catch (err) {
      Logger.warn('AudioRenderSink', `pause failed: ${(err as Error).message}`);
    }
  }

  async stop(): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      this.setPhase('stopped');
      return;
    }
    try {
      await player.stop();
    } catch (err) {
      Logger.warn('AudioRenderSink', `stop failed: ${(err as Error).message}`);
    }
    this.setPhase('stopped');
  }

  async seek(positionMs: number): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      await player.seek(positionMs);
      this.positionMs = positionMs;
      this.listener?.onPositionChanged(this.positionMs);
    } catch (err) {
      Logger.warn('AudioRenderSink', `seek failed: ${(err as Error).message}`);
    }
  }

  private async ensurePlayer(): Promise<media.AVPlayer> {
    if (this.player !== null) {
      return this.player;
    }
    try {
      const created: media.AVPlayer = await media.createAVPlayer();
      created.on('stateChange', (state: string) => {
        void this.onPlayerStateChange(state);
      });
      created.on('timeUpdate', (time: number) => {
        this.positionMs = time;
        this.listener?.onPositionChanged(time);
      });
      created.on('durationUpdate', (duration: number) => {
        if (duration > 0) {
          this.durationMs = duration;
          this.listener?.onDurationChanged(duration);
        }
      });
      created.on('error', (err: Error) => {
        this.emitError(`player error: ${err.message}`);
      });
      this.player = created;
      return created;
    } catch (err) {
      throw new Error(`createAVPlayer failed: ${(err as Error).message}`);
    }
  }

  private async onPlayerStateChange(state: string): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    if (state === 'initialized') {
      try {
        await player.prepare();
      } catch (err) {
        this.emitError(`prepare failed: ${(err as Error).message}`);
      }
      return;
    }
    if (state === 'prepared') {
      if (this.pendingSeekMs > 0) {
        const seekTarget: number = this.pendingSeekMs;
        this.pendingSeekMs = 0;
        try {
          await player.seek(seekTarget);
          this.positionMs = seekTarget;
          this.listener?.onPositionChanged(seekTarget);
        } catch (err) {
          Logger.warn('AudioRenderSink', `prepared seek failed: ${(err as Error).message}`);
        }
      }
      if (this.pendingAutoPlay) {
        this.pendingAutoPlay = false;
        try {
          await player.play();
        } catch (err) {
          this.emitError(`auto play failed: ${(err as Error).message}`);
        }
      } else if (this.migratePending) {
        this.migratePending = false;
      }
      return;
    }
    if (state === 'playing') {
      this.setPhase('playing');
      return;
    }
    if (state === 'paused' || state === 'stopped') {
      this.setPhase(state === 'paused' ? 'paused' : 'stopped');
      return;
    }
    if (state === 'completed') {
      this.setPhase('stopped');
      this.listener?.onCompleted();
    }
  }

  private setPhase(phase: PlaySinkPhase): void {
    if (this.phase === phase) {
      return;
    }
    this.phase = phase;
    this.listener?.onPhaseChanged(phase);
  }

  private emitError(message: string): void {
    Logger.warn('AudioRenderSink', message);
    this.setPhase('error');
    this.listener?.onError(message);
  }
}
