/**
 * 压缩音频字节有界环形缓冲（FetchWorker 写入，PlayWorker/Governor 读取统计）。
 */
export class CompressedRingBuffer {
  private readonly buffer: Uint8Array;
  private writePos: number = 0;
  private readPos: number = 0;
  private filled: number = 0;

  constructor(capacityBytes: number) {
    this.buffer = new Uint8Array(capacityBytes);
  }

  get availableBytes(): number {
    return this.filled;
  }

  get capacityBytes(): number {
    return this.buffer.length;
  }

  clear(): void {
    this.writePos = 0;
    this.readPos = 0;
    this.filled = 0;
  }

  write(data: Uint8Array, offset: number = 0, length?: number): number {
    const len: number = length !== undefined ? length : data.length - offset;
    if (len <= 0) {
      return 0;
    }
    const writable: number = Math.min(len, this.buffer.length - this.filled);
    let remaining: number = writable;
    let srcOffset: number = offset;
    while (remaining > 0) {
      const chunk: number = Math.min(remaining, this.buffer.length - this.writePos);
      this.buffer.set(data.subarray(srcOffset, srcOffset + chunk), this.writePos);
      this.writePos = (this.writePos + chunk) % this.buffer.length;
      srcOffset += chunk;
      remaining -= chunk;
      this.filled += chunk;
    }
    return writable;
  }

  /** 消费并丢弃可读字节（解码侧模拟消耗） */
  discard(length: number): number {
    const readable: number = Math.min(length, this.filled);
    this.readPos = (this.readPos + readable) % this.buffer.length;
    this.filled -= readable;
    return readable;
  }
}
