import { audio } from '@kit.AudioKit';
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
 * 播放引擎：已创建 AudioRenderer（符合 STREAM_USAGE_MUSIC 规范），
 * Subsonic 压缩流当前由 AVPlayer 负责解码与输出；待 AVCodec 解码入环后可切换 writeData 路径。
 */
export class PcmPlaybackEngine {
  private listener: PcmPlaybackEngineListener | null = null;
  private player: media.AVPlayer | null = null;
  private renderer: audio.AudioRenderer | null = null;
  private phase: EnginePhase = 'idle';
  private pendingAutoPlay: boolean = false;
  private positionMs: number = 0;
  private durationMs: number = 0;
  private progressTimerId: number = -1;

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
    await this.ensureRenderer();
    await this.ensurePlayer();
  }

  async release(): Promise<void> {
    this.stopProgressTimer();
    this.pendingAutoPlay = false;
    if (this.player !== null) {
      try {
        await this.player.release();
      } catch (err) {
        Logger.warn('PcmPlaybackEngine', `release player failed: ${(err as Error).message}`);
      }
      this.player = null;
    }
    if (this.renderer !== null) {
      try {
        await this.renderer.release();
      } catch (err) {
        Logger.warn('PcmPlaybackEngine', `release renderer failed: ${(err as Error).message}`);
      }
      this.renderer = null;
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
    this.stopProgressTimer();
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

  private async ensureRenderer(): Promise<audio.AudioRenderer> {
    if (this.renderer !== null) {
      return this.renderer;
    }
    const streamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
      channels: audio.AudioChannel.CHANNEL_2,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };
    const rendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    };
    const options: audio.AudioRendererOptions = { streamInfo, rendererInfo };
    try {
      this.renderer = await audio.createAudioRenderer(options);
      this.renderer.on('audioInterrupt', (event: audio.InterruptEvent) => {
        this.handleInterrupt(event);
      });
      return this.renderer;
    } catch (err) {
      throw new Error(`createAudioRenderer failed: ${(err as Error).message}`);
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
      this.player = created;
      return created;
    } catch (err) {
      throw new Error(`createAVPlayer failed: ${(err as Error).message}`);
    }
  }

  private handleInterrupt(event: audio.InterruptEvent): void {
    if (event.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
      if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        void this.pause();
      }
    } else if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_RESUME) {
      void this.play();
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
      this.setPhase('playing');
      this.startProgressTimer();
      return;
    }
    if (state === 'paused' || state === 'stopped') {
      this.stopProgressTimer();
      this.setPhase(state === 'paused' ? 'paused' : 'stopped');
      return;
    }
    if (state === 'completed') {
      this.stopProgressTimer();
      this.setPhase('stopped');
      this.listener?.onCompleted();
    }
  }

  private startProgressTimer(): void {
    this.stopProgressTimer();
    this.progressTimerId = setInterval(() => {
      this.listener?.onPositionChanged(this.positionMs);
    }, 500);
  }

  private stopProgressTimer(): void {
    if (this.progressTimerId >= 0) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = -1;
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
