import { fileIo, WriteOptions } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../common/Logger';
import { HttpTransport } from '../network/transport/HttpTransport';
import { PcmRingBuffer } from './PcmRingBuffer';

const STREAM_DIR: string = 'sonar_stream';

/**
 * 将 Subsonic 音频流下载到本地缓存，供解码/播放管线读取。
 * PCM 解码在 PcmPlaybackEngine 中通过系统 AVPlayer 拉流准备完成（见引擎内说明）。
 */
export class StreamDecoder {
  private context: common.UIAbilityContext | null = null;
  private localPath: string = '';
  private streamUrl: string = '';
  private cancelled: boolean = false;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  getLocalPath(): string {
    return this.localPath;
  }

  getStreamUrl(): string {
    return this.streamUrl;
  }

  reset(): void {
    this.cancelled = true;
    this.localPath = '';
    this.streamUrl = '';
    this.cancelled = false;
  }

  async prepare(streamUrl: string, songId: string, _ring: PcmRingBuffer): Promise<string> {
    this.streamUrl = streamUrl;
    if (this.context === null) {
      throw new Error('StreamDecoder missing context');
    }
    const safeId: string = songId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const dir: string = `${this.context.cacheDir}/${STREAM_DIR}`;
    try {
      fileIo.mkdirSync(dir, true);
    } catch (_err) {
    }
    this.localPath = `${dir}/${safeId}.audio`;
    await StreamDecoder.downloadToFile(streamUrl, this.localPath);
    return this.localPath;
  }

  private static async downloadToFile(remoteUrl: string, localPath: string): Promise<void> {
    const content: ArrayBuffer = await HttpTransport.requestBuffer(remoteUrl, 'binaryStream');
    try {
      fileIo.unlinkSync(localPath);
    } catch (_err) {
    }
    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      try {
        const writeOptions: WriteOptions = {
          offset: 0,
          length: content.byteLength
        };
        fileIo.writeSync(file.fd, content, writeOptions);
      } finally {
        try {
          fileIo.closeSync(file);
        } catch (_err) {
        }
      }
    } catch (err) {
      throw new Error(`write stream file failed: ${(err as Error).message}`);
    }
    Logger.debug('StreamDecoder', `cached stream bytes=${content.byteLength} path=${localPath}`);
  }
}
