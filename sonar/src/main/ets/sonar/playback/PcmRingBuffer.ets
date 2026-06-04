/**
 * 固定容量 S16LE 立体声 PCM 环形缓冲（字节粒度）。
 */
export class PcmRingBuffer {
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

  get freeBytes(): number {
    return this.buffer.length - this.filled;
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
    const writable: number = Math.min(len, this.freeBytes);
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

  read(target: ArrayBuffer, offset: number = 0, length?: number): number {
    const view: Uint8Array = new Uint8Array(target);
    const maxLen: number = length !== undefined ? length : view.length - offset;
    const readable: number = Math.min(maxLen, this.filled);
    let remaining: number = readable;
    let dstOffset: number = offset;
    while (remaining > 0) {
      const chunk: number = Math.min(remaining, this.buffer.length - this.readPos);
      view.set(this.buffer.subarray(this.readPos, this.readPos + chunk), dstOffset);
      this.readPos = (this.readPos + chunk) % this.buffer.length;
      dstOffset += chunk;
      remaining -= chunk;
      this.filled -= chunk;
    }
    return readable;
  }
}
