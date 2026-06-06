import { media } from '@kit.MediaKit';
import { fileUri } from '@kit.CoreFileKit';
import { Logger } from '../common/Logger';
export type EnginePhase = 'idle' | 'loading' | 'playing' | 'paused' | 'stopped' | 'error';

export interface PcmPlaybackEngineListener {
  onPhaseChanged(phase: EnginePhase): void;
  onPositionChanged(positionMs: number): void;
  onDurationChanged(durationMs: number): void;
  onCompleted(): void;
  onError(message: string): void;
}

/**
 * 播放引擎：Subsonic 压缩流由 AVPlayer 拉流解码输出；待 AVCodec 入环后可接 AudioRenderer writeData。
 */
export class PcmPlaybackEngine {
  private listener: PcmPlaybackEngineListener | null = null;
  private player: media.AVPlayer | null = null;
  private phase: EnginePhase = 'idle';
  private pendingAutoPlay: boolean = false;
  private positionMs: number = 0;
  private durationMs: number = 0;
  private networkBuffering: boolean = false;

  setListener(listener: PcmPlaybackEngineListener | null): void {
    this.listener = listener;
  }

  getPhase(): EnginePhase {
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
    this.networkBuffering = false;
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (err) {
        Logger.warn('PcmPlaybackEngine', `release player failed: ${(err as Error).message}`);
      }
      this.player = null;
    }
    this.setPhase('idle');
    this.positionMs = 0;
    this.durationMs = 0;
  }

  async loadStreamUrl(streamUrl: string, autoPlay: boolean): Promise<void> {
    const player: media.AVPlayer = await this.ensurePlayer();
    this.pendingAutoPlay = autoPlay;
    this.setPhase('loading');
    this.positionMs = 0;
    try {
      await player.reset();
    } catch (err) {
      Logger.warn('PcmPlaybackEngine', `reset failed: ${(err as Error).message}`);
    }
    player.url = streamUrl;
  }

  async loadLocalPath(localPath: string, autoPlay: boolean): Promise<void> {
    const uri: string = fileUri.getUriFromPath(localPath);
    await this.loadStreamUrl(uri, autoPlay);
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
    const player: media.AVPlayer = await this.ensurePlayer();
    if (player.state !== 'playing') {
      return;
    }
    try {
      await player.pause();
    } catch (err) {
      Logger.warn('PcmPlaybackEngine', `pause failed: ${(err as Error).message}`);
    }
  }

  async stop(): Promise<void> {
    this.networkBuffering = false;
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      this.setPhase('stopped');
      return;
    }
    try {
      await player.stop();
    } catch (err) {
      Logger.warn('PcmPlaybackEngine', `stop failed: ${(err as Error).message}`);
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
      Logger.warn('PcmPlaybackEngine', `seek failed: ${(err as Error).message}`);
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
      created.on('bufferingUpdate', (infoType: media.BufferingInfoType, _value: number) => {
        this.onBufferingUpdate(infoType);
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

  private onBufferingUpdate(infoType: media.BufferingInfoType): void {
    if (infoType === media.BufferingInfoType.BUFFERING_START) {
      this.networkBuffering = true;
      this.setPhase('loading');
      return;
    }
    if (infoType === media.BufferingInfoType.BUFFERING_END) {
      this.networkBuffering = false;
      const player: media.AVPlayer | null = this.player;
      if (player !== null && player.state === 'playing') {
        this.setPhase('playing');
      }
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
      if (this.pendingAutoPlay) {
        this.pendingAutoPlay = false;
        try {
          await player.play();
        } catch (err) {
          this.emitError(`auto play failed: ${(err as Error).message}`);
        }
      }
      return;
    }
    if (state === 'playing') {
      if (!this.networkBuffering) {
        this.setPhase('playing');
      }
      return;
    }
    if (state === 'paused' || state === 'stopped') {
      this.networkBuffering = false;
      this.setPhase(state === 'paused' ? 'paused' : 'stopped');
      return;
    }
    if (state === 'completed') {
      this.networkBuffering = false;
      this.setPhase('stopped');
      this.listener?.onCompleted();
    }
  }

  private setPhase(phase: EnginePhase): void {
    if (this.phase === phase) {
      return;
    }
    this.phase = phase;
    this.listener?.onPhaseChanged(phase);
  }

  private emitError(message: string): void {
    Logger.warn('PcmPlaybackEngine', message);
    this.setPhase('error');
    this.listener?.onError(message);
  }
}
