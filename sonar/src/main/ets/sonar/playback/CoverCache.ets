import { common } from '@kit.AbilityKit';
import { fileIo, WriteOptions } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { EndpointType } from '../auth/AuthStore';
import { AuthContext } from '../network/auth/AuthContext';
import { HttpTransport } from '../network/transport/HttpTransport';
import { CacheFileUtil } from '../common/CacheFileUtil';
import { Logger } from '../common/Logger';

const COVER_SIZE: number = 320;
const MAX_MEMORY_CACHE: number = 32;
const COVER_DIR: string = 'sonar_cover';

export class CoverDisplaySource {
  readonly pixelMap: image.PixelMap | null;
  readonly revision: number;

  constructor(pixelMap: image.PixelMap | null, revision: number) {
    this.pixelMap = pixelMap;
    this.revision = revision;
  }
}

interface CoverCacheEntry {
  pixelMap: image.PixelMap;
}

export class CoverCache {
  private static context: common.UIAbilityContext | null = null;
  private static memoryCache: Map<string, CoverCacheEntry> = new Map<string, CoverCacheEntry>();
  private static memoryOrder: string[] = [];
  private static inFlight: Map<string, Promise<image.PixelMap | null>> = new Map<string, Promise<image.PixelMap | null>>();
  private static revision: number = 0;
  private static pinnedCoverArtId: string = '';

  static setContext(context: common.UIAbilityContext): void {
    CoverCache.context = context;
  }

  static getRevision(): number {
    return CoverCache.revision;
  }

  /** 播放中固定当前封面，避免 LRU 逐出导致 AVSession 重复写入无效 mediaImage */
  static pin(coverArtId: string): void {
    if (coverArtId.length === 0) {
      return;
    }
    CoverCache.pinnedCoverArtId = coverArtId;
    CoverCache.touch(coverArtId);
  }

  static unpin(): void {
    CoverCache.pinnedCoverArtId = '';
  }

  static getDisplaySource(coverArtId: string): CoverDisplaySource {
    if (coverArtId.length === 0) {
      return new CoverDisplaySource(null, CoverCache.revision);
    }
    const entry: CoverCacheEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    if (entry !== undefined) {
      CoverCache.touch(coverArtId);
      return new CoverDisplaySource(entry.pixelMap, CoverCache.revision);
    }
    return new CoverDisplaySource(null, CoverCache.revision);
  }

  static async load(coverArtId: string): Promise<image.PixelMap | null> {
    if (coverArtId.length === 0) {
      return null;
    }
    const cached: CoverCacheEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    if (cached !== undefined) {
      CoverCache.touch(coverArtId);
      return cached.pixelMap;
    }
    const inFlight: Promise<image.PixelMap | null> | undefined = CoverCache.inFlight.get(coverArtId);
    if (inFlight !== undefined) {
      return await inFlight;
    }
    const task: Promise<image.PixelMap | null> = CoverCache.loadInternal(coverArtId);
    CoverCache.inFlight.set(coverArtId, task);
    try {
      return await task;
    } finally {
      CoverCache.inFlight.delete(coverArtId);
    }
  }

  static async releaseAll(): Promise<void> {
    const keys: string[] = Array.from(CoverCache.memoryCache.keys());
    for (let i: number = 0; i < keys.length; i++) {
      const entry: CoverCacheEntry | undefined = CoverCache.memoryCache.get(keys[i]);
      if (entry !== undefined) {
        try {
          await entry.pixelMap.release();
        } catch (_err) {
        }
      }
    }
    CoverCache.memoryCache.clear();
    CoverCache.memoryOrder = [];
  }

  private static async loadInternal(coverArtId: string): Promise<image.PixelMap | null> {
    const localPath: string = CoverCache.localPath(coverArtId);
    if (localPath.length > 0 && CacheFileUtil.fileExists(localPath)) {
      const pm: image.PixelMap | null = await CoverCache.decodeFile(localPath);
      if (pm !== null) {
        CoverCache.put(coverArtId, pm);
        CoverCache.revision++;
      }
      return pm;
    }
    try {
      await CoverCache.downloadToFile(coverArtId, localPath);
      const pm: image.PixelMap | null = await CoverCache.decodeFile(localPath);
      if (pm !== null) {
        CoverCache.put(coverArtId, pm);
        CoverCache.revision++;
      }
      return pm;
    } catch (err) {
      Logger.warn('CoverCache', `load failed id=${coverArtId}: ${(err as Error).message}`);
      return null;
    }
  }

  private static put(coverArtId: string, pixelMap: image.PixelMap): void {
    if (CoverCache.memoryCache.has(coverArtId)) {
      CoverCache.memoryCache.delete(coverArtId);
      const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
      if (idx >= 0) {
        CoverCache.memoryOrder.splice(idx, 1);
      }
    }
    CoverCache.memoryCache.set(coverArtId, { pixelMap });
    CoverCache.memoryOrder.push(coverArtId);
    while (CoverCache.memoryOrder.length > MAX_MEMORY_CACHE) {
      const evictId: string | null = CoverCache.pickEvictCandidate();
      if (evictId === null) {
        break;
      }
      CoverCache.evict(evictId);
    }
  }

  private static pickEvictCandidate(): string | null {
    for (let i: number = 0; i < CoverCache.memoryOrder.length; i++) {
      const id: string = CoverCache.memoryOrder[i];
      if (id !== CoverCache.pinnedCoverArtId) {
        return id;
      }
    }
    return null;
  }

  private static evict(coverArtId: string): void {
    const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
    if (idx >= 0) {
      CoverCache.memoryOrder.splice(idx, 1);
    }
    const entry: CoverCacheEntry | undefined = CoverCache.memoryCache.get(coverArtId);
    CoverCache.memoryCache.delete(coverArtId);
    if (entry !== undefined) {
      void entry.pixelMap.release();
    }
  }

  private static touch(coverArtId: string): void {
    const idx: number = CoverCache.memoryOrder.indexOf(coverArtId);
    if (idx >= 0) {
      CoverCache.memoryOrder.splice(idx, 1);
      CoverCache.memoryOrder.push(coverArtId);
    }
  }

  private static localPath(coverArtId: string): string {
    if (CoverCache.context === null) {
      return '';
    }
    const safeId: string = CacheFileUtil.sanitizeId(coverArtId);
    return `${CoverCache.context.cacheDir}/${COVER_DIR}/${safeId}.jpg`;
  }

  private static async downloadToFile(coverArtId: string, localPath: string): Promise<void> {
    CacheFileUtil.ensureParentDir(localPath);
    const content: ArrayBuffer = await HttpTransport.requestBufferWithFallback({
      buildUrl: (ep: EndpointType): string =>
        AuthContext.buildMediaUrl('getCoverArt', ['id', coverArtId, 'size', String(COVER_SIZE)], undefined, ep),
      profile: 'binarySmall'
    });
      CacheFileUtil.removeIfExists(localPath);
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
        throw new Error(`write cover file failed: ${(err as Error).message}`);
      }
  }

  private static async decodeFile(path: string): Promise<image.PixelMap | null> {
    try {
      const source: image.ImageSource = image.createImageSource(path);
      const pm: image.PixelMap = await source.createPixelMap({
        desiredSize: { width: COVER_SIZE, height: COVER_SIZE }
      });
      await source.release();
      return pm;
    } catch (err) {
      Logger.warn('CoverCache', `decode failed: ${(err as Error).message}`);
      return null;
    }
  }
}
