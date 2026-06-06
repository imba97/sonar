import { common } from '@kit.AbilityKit';
import { fileIo, WriteOptions } from '@kit.CoreFileKit';

const STREAM_DIR: string = 'sonar_stream';

export class StreamCacheFile {
  private context: common.UIAbilityContext | null = null;
  private localPath: string = '';
  private fileFd: number = -1;
  private writeOffset: number = 0;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  getLocalPath(): string {
    return this.localPath;
  }

  getWriteOffset(): number {
    return this.writeOffset;
  }

  openForSong(songId: string, byteOffset: number = 0): void {
    this.close();
    if (this.context === null) {
      return;
    }
    const safeId: string = songId.replace(/[^a-zA-Z0-9_-]/g, '_');
    const dir: string = `${this.context.cacheDir}/${STREAM_DIR}`;
    try {
      fileIo.mkdirSync(dir, true);
    } catch (_err) {
    }
    this.localPath = `${dir}/${safeId}.audio`;
    this.writeOffset = byteOffset;
    if (byteOffset === 0) {
      try {
        fileIo.unlinkSync(this.localPath);
      } catch (_err) {
      }
    }
    try {
      const file = fileIo.openSync(this.localPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      this.fileFd = file.fd;
      if (byteOffset > 0) {
        try {
          const stat = fileIo.statSync(this.localPath);
          if (stat.size < byteOffset) {
            fileIo.truncateSync(this.fileFd, byteOffset);
          }
          this.writeOffset = Math.max(stat.size, byteOffset);
        } catch (_err) {
          this.writeOffset = byteOffset;
        }
      }
    } catch (_err) {
      this.fileFd = -1;
    }
  }

  appendChunk(chunk: ArrayBuffer): void {
    if (this.fileFd < 0) {
      return;
    }
    try {
      const writeOptions: WriteOptions = {
        offset: this.writeOffset,
        length: chunk.byteLength
      };
      fileIo.writeSync(this.fileFd, chunk, writeOptions);
      this.writeOffset += chunk.byteLength;
    } catch (_err) {
    }
  }

  close(): void {
    if (this.fileFd >= 0) {
      try {
        fileIo.closeSync(this.fileFd);
      } catch (_err) {
      }
      this.fileFd = -1;
    }
    this.localPath = '';
    this.writeOffset = 0;
  }
}
