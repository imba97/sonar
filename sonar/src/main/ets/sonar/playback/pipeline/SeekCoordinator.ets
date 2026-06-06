import { estimateByteOffset } from './PlaybackBufferPolicy';

export interface SeekPlan {
  byteOffset: number;
  restartFetch: boolean;
}

/** Seek 编排：已缓存区间内直接 seek；否则 Range 重拉 */
export class SeekCoordinator {
  planSeek(positionMs: number, downloadedBytes: number, durationMs: number): SeekPlan {
    if (positionMs <= 0 || downloadedBytes <= 0 || durationMs <= 0) {
      return { byteOffset: 0, restartFetch: positionMs > 0 };
    }
    const targetOffset: number = estimateByteOffset(positionMs, durationMs, downloadedBytes);
    const restartFetch: boolean = targetOffset >= downloadedBytes - 4096;
    return { byteOffset: targetOffset, restartFetch: restartFetch };
  }
}
