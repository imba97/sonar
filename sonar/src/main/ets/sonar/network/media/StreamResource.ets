import { EndpointType } from '../../auth/AuthStore';
import { AuthContext } from '../auth/AuthContext';
import { CancelToken } from '../transport/CancelToken';

export interface StreamRequestSpec {
  url: string;
  headers: Record<string, string>;
}

export class StreamResource {
  readonly songId: string;
  private cancelTokenRef: CancelToken;
  byteOffset: number;
  private endpoint: EndpointType;
  private readonly maxBitRate: number;

  constructor(songId: string, endpoint: EndpointType, byteOffset: number, maxBitRate: number,
    cancelToken: CancelToken) {
    this.songId = songId;
    this.endpoint = endpoint;
    this.byteOffset = byteOffset;
    this.maxBitRate = maxBitRate;
    this.cancelTokenRef = cancelToken;
  }

  get cancelToken(): CancelToken {
    return this.cancelTokenRef;
  }

  /** Fetch 取消后换新 token，同曲目续拉 */
  renewCancelToken(): CancelToken {
    this.cancelTokenRef = new CancelToken();
    return this.cancelTokenRef;
  }

  getEndpoint(): EndpointType {
    return this.endpoint;
  }

  resolveRequest(): StreamRequestSpec {
    const params: string[] = ['id', this.songId];
    if (this.maxBitRate > 0) {
      params.push('maxBitRate', String(this.maxBitRate));
    }
    const url: string = AuthContext.buildMediaUrl('stream', params, undefined, this.endpoint);
    const headers: Record<string, string> = {};
    if (this.byteOffset > 0) {
      headers['Range'] = `bytes=${this.byteOffset}-`;
    }
    const spec: StreamRequestSpec = { url: url, headers: headers };
    return spec;
  }

  migrate(newEndpoint: EndpointType): void {
    this.endpoint = newEndpoint;
  }
}
