/** 起播：可播放时长 ≥ 此值才开始出声 */
export const TARGET_BUFFER_SECONDS: number = 10;

/** 播放中维持前瞻缓冲目标（秒） */
export const PLAYBACK_BUFFER_SECONDS: number = 10;

/** 低于此值 → isBuffering=true */
export const REBUFFER_LOW_WATERMARK_SECONDS: number = 3;

/** ≈10s @ 48kHz S16LE stereo */
export const PCM_RING_CAPACITY_BYTES: number = 1024 * 1024 * 2;

/** ≈10s @ 320kbps */
export const COMPRESSED_RING_CAPACITY_BYTES: number = 512 * 1024;

export const PCM_BYTES_PER_SECOND: number = 48000 * 2 * 2;

/** 默认 Subsonic 流码率粗估（bps） */
export const DEFAULT_STREAM_BITRATE_BPS: number = 320000;

export function estimatePlayableMsFromCompressedBytes(compressedBytes: number,
  bitrateBps: number = DEFAULT_STREAM_BITRATE_BPS): number {
  if (compressedBytes <= 0 || bitrateBps <= 0) {
    return 0;
  }
  return Math.floor((compressedBytes * 8 * 1000) / bitrateBps);
}

export function estimateByteOffset(positionMs: number, durationMs: number, contentLength: number): number {
  if (positionMs <= 0 || durationMs <= 0 || contentLength <= 0) {
    return 0;
  }
  const ratio: number = Math.min(1, Math.max(0, positionMs / durationMs));
  return Math.floor(ratio * contentLength);
}
