import { Logger } from '../common/Logger';

/** Set 去重 + FIFO 串行下载队列，SongCache / CoverCache 共用 */
export class CacheDownloadQueue {
  private readonly pending: Set<string> = new Set<string>();
  private readonly queue: string[] = [];
  private processing: boolean = false;

  contains(id: string): boolean {
    return this.pending.has(id);
  }

  enqueue(id: string): boolean {
    if (id.length === 0 || this.pending.has(id)) {
      return false;
    }
    this.pending.add(id);
    this.queue.push(id);
    return true;
  }

  remove(id: string): void {
    if (!this.pending.has(id)) {
      return;
    }
    this.pending.delete(id);
    const idx: number = this.queue.indexOf(id);
    if (idx >= 0) {
      this.queue.splice(idx, 1);
    }
  }

  /** 清空队列并强制解锁；仅供 release()/reset 路径使用，避免 handler 抛错后 processing 卡死 */
  clear(): void {
    this.pending.clear();
    this.queue.length = 0;
    this.processing = false;
  }

  async process(handler: (id: string) => Promise<void>): Promise<void> {
    if (this.processing) {
      return;
    }
    this.processing = true;
    try {
      while (this.queue.length > 0) {
        const id: string | undefined = this.queue.shift();
        if (id === undefined || id.length === 0) {
          continue;
        }
        this.pending.delete(id);
        // 单项 handler 抛错不应中断整条队列；吞掉 + warn，继续处理后续项
        try {
          await handler(id);
        } catch (err) {
          Logger.warn('CacheDownloadQueue', `handler failed id=${id}: ${(err as Error).message}`);
        }
      }
    } finally {
      this.processing = false;
    }
  }
}
