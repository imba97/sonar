import { common } from '@kit.AbilityKit';
import { Logger } from '../../common/Logger';
import { StreamResource } from '../../network/media/StreamResource';
import { CancelToken } from '../../network/transport/CancelToken';
import { EndpointChangeEvent } from '../../network/routing/EndpointTypes';
import { AudioRenderSink } from './AudioRenderSink';
import { BufferGovernor, BufferGovernorListener } from './BufferGovernor';
import { COMPRESSED_RING_CAPACITY_BYTES, estimateByteOffset, PCM_RING_CAPACITY_BYTES } from './PlaybackBufferPolicy';
import { CompressedRingBuffer } from './CompressedRingBuffer';
import { FetchWorker } from './FetchWorker';
import { PipelineMetrics } from './PipelineMetrics';
import { PlayWorker, PlayWorkerCallbacks } from './PlayWorker';
import { PlaySinkPhase } from './AudioRenderSink';
import { PcmRingBuffer } from '../PcmRingBuffer';
import { SeekCoordinator } from './SeekCoordinator';
import { StreamCacheFile } from './StreamCacheFile';

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

/**
 * 播放管线编排：FetchWorker ∥ PlayWorker + BufferGovernor。
 */
export class PipelineOrchestrator implements BufferGovernorListener {
  private context: common.UIAbilityContext | null = null;
  private callbacks: PipelineOrchestratorCallbacks | null = null;
  private readonly governor: BufferGovernor = new BufferGovernor();
  private readonly compressedRing: CompressedRingBuffer =
    new CompressedRingBuffer(COMPRESSED_RING_CAPACITY_BYTES);
  private readonly pcmRing: PcmRingBuffer = new PcmRingBuffer(PCM_RING_CAPACITY_BYTES);
  private readonly cacheFile: StreamCacheFile = new StreamCacheFile();
  private readonly audioSink: AudioRenderSink = new AudioRenderSink();
  private readonly playWorker: PlayWorker = new PlayWorker(this.audioSink);
  private readonly seekCoordinator: SeekCoordinator = new SeekCoordinator();
  private activeStreamResource: StreamResource | null = null;
  private fetchRunning: boolean = false;
  private migrating: boolean = false;
  private frozenPositionMs: number = 0;
  private wasPlayingBeforeBuffer: boolean = false;
  private durationMs: number = 0;
  private downloadedBytes: number = 0;
  private contentLength: number = 0;
  private fetchCancelToken: CancelToken | null = null;

  constructor() {
    this.governor.setListener(this);
    this.playWorker.setGovernor(this.governor);
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
    this.cacheFile.setContext(context);
  }

  setCallbacks(callbacks: PipelineOrchestratorCallbacks | null): void {
    this.callbacks = callbacks;
    const playCallbacks: PlayWorkerCallbacks = {
      onPhaseChanged: (phase: PlaySinkPhase): void => {
        this.callbacks?.onPhaseChanged(phase);
      },
      onPositionChanged: (positionMs: number): void => {
        if (!this.governor.isBuffering()) {
          this.callbacks?.onPositionChanged(positionMs);
        }
      },
      onDurationChanged: (durationMs: number): void => {
        this.durationMs = durationMs;
        this.governor.setDurationMs(durationMs);
        this.callbacks?.onDurationChanged(durationMs);
      },
      onCompleted: (): void => {
        this.callbacks?.onCompleted();
      },
      onError: (message: string): void => {
        this.callbacks?.onError(message);
      }
    };
    this.playWorker.setCallbacks(playCallbacks);
  }

  async initialize(): Promise<void> {
    await this.playWorker.initialize();
  }

  async release(): Promise<void> {
    await this.cancel(/* keepStreamResource */ false);
    await this.playWorker.release();
    this.governor.reset();
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
    this.governor.reset();
    this.governor.setDurationMs(durationMs);
    this.compressedRing.clear();
    this.pcmRing.clear();
    this.cacheFile.openForSong(streamResource.songId, streamResource.byteOffset);
    this.downloadedBytes = streamResource.byteOffset;
    this.contentLength = 0;
    const url: string = streamResource.resolveRequest().url;
    this.playWorker.scheduleStart(url, autoPlay, 0);
    this.startFetch(streamResource);
    PipelineMetrics.recordTrackStart();
  }

  async cancel(keepStreamResource: boolean = false): Promise<void> {
    this.cancelFetchToken();
    if (this.activeStreamResource !== null && !keepStreamResource) {
      this.activeStreamResource.cancelToken.cancel();
    }
    this.fetchRunning = false;
    await this.playWorker.stop();
    this.compressedRing.clear();
    this.pcmRing.clear();
    this.cacheFile.close();
    this.governor.reset();
    if (!keepStreamResource) {
      this.activeStreamResource = null;
    }
  }

  /** 切网无感续播：同 StreamResource，Range 续拉 + 进度冻结 */
  async migrateInPlace(frozenPositionMs: number, wasPlaying: boolean): Promise<void> {
    if (this.activeStreamResource === null || this.migrating) {
      return;
    }
    this.migrating = true;
    this.frozenPositionMs = frozenPositionMs;
    this.wasPlayingBeforeBuffer = wasPlaying;
    Logger.info('PipelineOrchestrator',
      `migrateInPlace song=${this.activeStreamResource.songId} pos=${frozenPositionMs}`);
    this.governor.forceEnterBuffering(frozenPositionMs);
    await this.cancelFetchOnly();
    const resource: StreamResource = this.activeStreamResource;
    const totalLength: number = this.contentLength > 0 ? this.contentLength : this.downloadedBytes;
    if (this.durationMs > 0 && totalLength > 0) {
      resource.byteOffset = estimateByteOffset(frozenPositionMs, this.durationMs, totalLength);
    } else {
      resource.byteOffset = 0;
    }
    this.compressedRing.clear();
    this.cacheFile.openForSong(resource.songId, resource.byteOffset);
    this.downloadedBytes = resource.byteOffset;
    const url: string = resource.resolveRequest().url;
    this.playWorker.scheduleMigrate(url, frozenPositionMs, wasPlaying);
    this.startFetch(resource);
    PipelineMetrics.recordMigrate();
    this.migrating = false;
  }

  async onNetworkPathChanged(_event: EndpointChangeEvent): Promise<void> {
    const frozenMs: number = this.callbacks?.getAuthoritativePositionMs() ?? this.frozenPositionMs;
    const phase: string = this.callbacks?.getCurrentPhase() ?? 'idle';
    const wasPlaying: boolean = phase === 'playing';
    if (this.activeStreamResource === null) {
      return;
    }
    await this.migrateInPlace(frozenMs, wasPlaying);
  }

  async seek(positionMs: number): Promise<void> {
    if (this.activeStreamResource === null) {
      return;
    }
    const plan = this.seekCoordinator.planSeek(positionMs, this.downloadedBytes, this.durationMs);
    if (plan.restartFetch) {
      this.governor.forceEnterBuffering(positionMs);
      await this.cancelFetchOnly();
      this.activeStreamResource.byteOffset = plan.byteOffset;
      this.compressedRing.clear();
      this.cacheFile.openForSong(this.activeStreamResource.songId, plan.byteOffset);
      this.downloadedBytes = plan.byteOffset;
      const url: string = this.activeStreamResource.resolveRequest().url;
      const wasPlaying: boolean = this.callbacks?.getCurrentPhase() === 'playing';
      this.playWorker.scheduleMigrate(url, positionMs, wasPlaying);
      this.startFetch(this.activeStreamResource);
    } else {
      await this.playWorker.seek(positionMs);
    }
    PipelineMetrics.recordSeek();
  }

  async play(): Promise<void> {
    await this.playWorker.play();
  }

  async pause(): Promise<void> {
    await this.playWorker.pause();
  }

  getPositionMs(): number {
    if (this.governor.isBuffering()) {
      return this.frozenPositionMs;
    }
    return this.playWorker.getPositionMs();
  }

  getDurationMs(): number {
    const fromSink: number = this.playWorker.getDurationMs();
    return fromSink > 0 ? fromSink : this.durationMs;
  }

  getPhase(): PlaySinkPhase {
    return this.playWorker.getPhase();
  }

  isBuffering(): boolean {
    return this.governor.isBuffering();
  }

  onEnterBuffering(frozenPositionMs: number): void {
    if (frozenPositionMs > 0) {
      this.frozenPositionMs = frozenPositionMs;
    } else {
      this.frozenPositionMs = this.callbacks?.getAuthoritativePositionMs() ?? this.playWorker.getPositionMs();
    }
    this.callbacks?.onEnterBuffering(this.frozenPositionMs);
  }

  onExitBuffering(): void {
    this.callbacks?.onExitBuffering();
    if (this.wasPlayingBeforeBuffer) {
      void this.playWorker.play();
      this.wasPlayingBeforeBuffer = false;
    }
  }

  onReadyToPlay(): void {
    this.playWorker.onGovernorReadyToPlay();
  }

  private async cancelFetchOnly(): Promise<void> {
    this.cancelFetchToken();
    this.fetchRunning = false;
    this.governor.setFetchActive(false);
  }

  private cancelFetchToken(): void {
    if (this.fetchCancelToken !== null) {
      this.fetchCancelToken.cancel();
      this.fetchCancelToken = null;
    }
  }

  private startFetch(streamResource: StreamResource): void {
    this.cancelFetchToken();
    this.fetchCancelToken = new CancelToken();
    this.fetchRunning = true;
    this.governor.setFetchActive(true);
    const fetchToken: CancelToken = this.fetchCancelToken as CancelToken;
    FetchWorker.run(streamResource, {
      onProgress: (progress): void => {
        this.downloadedBytes = progress.downloadedBytes;
        if (progress.contentLength !== undefined && progress.contentLength > 0) {
          this.contentLength = progress.contentLength;
        }
        this.governor.onFetchProgress(progress.downloadedBytes, progress.contentLength);
      },
      onChunk: (chunk: ArrayBuffer): void => {
        this.cacheFile.appendChunk(chunk);
        this.compressedRing.write(new Uint8Array(chunk));
      },
      onComplete: (): void => {
        this.fetchRunning = false;
        this.governor.setFetchActive(false);
        PipelineMetrics.recordFetchComplete();
      },
      onError: (err: Error): void => {
        this.fetchRunning = false;
        this.governor.setFetchActive(false);
        Logger.warn('PipelineOrchestrator', `fetch error: ${err.message}`);
        PipelineMetrics.recordFetchError();
      }
    }, fetchToken);
  }
}
