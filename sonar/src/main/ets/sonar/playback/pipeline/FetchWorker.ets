import { Logger } from '../../common/Logger';
import { StreamResource } from '../../network/media/StreamResource';
import { HttpTransport } from '../../network/transport/HttpTransport';
import { CancelToken } from '../../network/transport/CancelToken';

export interface FetchProgress {
  downloadedBytes: number;
  contentLength?: number;
}

export interface FetchWorkerCallbacks {
  onProgress?: (progress: FetchProgress) => void;
  onComplete?: () => void;
  onError?: (err: Error) => void;
}

/**
 * 音频流 Fetch 生产者；仅经 HttpTransport.openStream，禁止自建 http 客户端。
 */
export class FetchWorker {
  static run(streamResource: StreamResource, callbacks: FetchWorkerCallbacks): CancelToken {
    const cancelToken: CancelToken = streamResource.cancelToken;
    let downloadedBytes: number = streamResource.byteOffset;
    let contentLength: number | undefined;

    const spec = streamResource.resolveRequest();
    Logger.info('FetchWorker', `start songId=${streamResource.songId} offset=${streamResource.byteOffset}`);

    HttpTransport.openStream({
      url: spec.url,
      byteOffset: streamResource.byteOffset,
      cancelToken,
      onHeaders: (headers: Record<string, string>): void => {
        const lengthHeader: string | undefined = headers['Content-Length'] ?? headers['content-length'];
        if (lengthHeader !== undefined) {
          const parsed: number = Number.parseInt(lengthHeader, 10);
          if (!Number.isNaN(parsed)) {
            contentLength = parsed;
          }
        }
      },
      onChunk: (chunk: ArrayBuffer): void => {
        downloadedBytes += chunk.byteLength;
        if (callbacks.onProgress !== undefined) {
          callbacks.onProgress({ downloadedBytes, contentLength });
        }
      },
      onComplete: (): void => {
        if (callbacks.onComplete !== undefined) {
          callbacks.onComplete();
        }
      },
      onError: (err: Error): void => {
        if (callbacks.onError !== undefined) {
          callbacks.onError(err);
        }
      }
    });

    return cancelToken;
  }
}
