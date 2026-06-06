import { Logger } from '../../common/Logger';
import { AuthContext } from '../../network/auth/AuthContext';
import { EndpointRouter } from '../../network/routing/EndpointRouter';
import { HttpTransport } from '../../network/transport/HttpTransport';
import { CancelToken } from '../../network/transport/CancelToken';

/**
 * 可选：local boost 态预拉下一首压缩流头部（不阻塞主 Fetch）。
 */
export class PrefetchWorker {
  static prefetchNextSong(songId: string): CancelToken | null {
    if (!EndpointRouter.isLocalBoostActive()) {
      return null;
    }
    const cancelToken: CancelToken = new CancelToken();
    const url: string = AuthContext.buildMediaUrl('stream', ['id', songId], undefined, 'local');
    Logger.debug('PrefetchWorker', `prefetch songId=${songId}`);
    HttpTransport.openStream({
      url: url,
      byteOffset: 0,
      cancelToken,
      onChunk: (_chunk: ArrayBuffer): void => {
        cancelToken.cancel();
      },
      onComplete: (): void => {
      },
      onError: (_err: Error): void => {
      }
    });
    return cancelToken;
  }
}
