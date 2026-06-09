import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Logger } from '../common/Logger';
import { SongCacheStore } from './SongCacheStore';
import { AutoCacheMode, CacheLimitGb } from './SongCacheTypes';

const STORE_NAME: string = 'sonar_song_cache';
const KEY_AUTO_CACHE_MODE: string = 'auto_cache_mode';
const KEY_LIMIT_GB: string = 'limit_gb';

const DEFAULT_AUTO_CACHE_MODE: AutoCacheMode = 'wifi_only';
const DEFAULT_LIMIT_GB: CacheLimitGb = 2;

export class SongCacheSettingsStore {
  private static instance: SongCacheSettingsStore | null = null;
  private store: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  private autoCacheMode: AutoCacheMode = DEFAULT_AUTO_CACHE_MODE;
  private limitGb: CacheLimitGb = DEFAULT_LIMIT_GB;

  private constructor() {
  }

  static getInstance(): SongCacheSettingsStore {
    if (SongCacheSettingsStore.instance === null) {
      SongCacheSettingsStore.instance = new SongCacheSettingsStore();
    }
    return SongCacheSettingsStore.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    if (this.store !== null) {
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.reload();
    } catch (err) {
      Logger.error('SongCacheSettingsStore', `init failed: ${(err as Error).message}`);
    }
  }

  async ensureReady(): Promise<void> {
    if (this.store !== null) {
      return;
    }
    if (this.context === null) {
      return;
    }
    await this.init(this.context);
  }

  private async reload(): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      const modeRaw: string = (await this.store.get(KEY_AUTO_CACHE_MODE, DEFAULT_AUTO_CACHE_MODE)) as string;
      this.autoCacheMode = SongCacheSettingsStore.normalizeMode(modeRaw);
      const limitRaw: number = (await this.store.get(KEY_LIMIT_GB, DEFAULT_LIMIT_GB)) as number;
      this.limitGb = SongCacheSettingsStore.normalizeLimitGb(limitRaw);
      SongCacheStore.publishLimitGb(this.limitGb);
      SongCacheStore.publishAutoCacheMode(this.autoCacheMode);
    } catch (err) {
      Logger.warn('SongCacheSettingsStore', `reload failed: ${(err as Error).message}`);
      this.autoCacheMode = DEFAULT_AUTO_CACHE_MODE;
      this.limitGb = DEFAULT_LIMIT_GB;
    }
  }

  getAutoCacheMode(): AutoCacheMode {
    return this.autoCacheMode;
  }

  getLimitGb(): CacheLimitGb {
    return this.limitGb;
  }

  getLimitBytes(): number {
    return this.limitGb * 1024 * 1024 * 1024;
  }

  async setAutoCacheMode(mode: AutoCacheMode): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    this.autoCacheMode = mode;
    try {
      await this.store.put(KEY_AUTO_CACHE_MODE, mode);
    } catch (err) {
      Logger.warn('SongCacheSettingsStore', `setAutoCacheMode put failed: ${(err as Error).message}`);
      return;
    }
    try {
      await this.store.flush();
    } catch (err) {
      Logger.warn('SongCacheSettingsStore', `setAutoCacheMode flush failed: ${(err as Error).message}`);
      return;
    }
    SongCacheStore.publishAutoCacheMode(mode);
  }

  async setLimitGb(limitGb: CacheLimitGb): Promise<void> {
    await this.ensureReady();
    if (this.store === null) {
      return;
    }
    this.limitGb = limitGb;
    try {
      await this.store.put(KEY_LIMIT_GB, limitGb);
    } catch (err) {
      Logger.warn('SongCacheSettingsStore', `setLimitGb put failed: ${(err as Error).message}`);
      return;
    }
    try {
      await this.store.flush();
    } catch (err) {
      Logger.warn('SongCacheSettingsStore', `setLimitGb flush failed: ${(err as Error).message}`);
      return;
    }
    SongCacheStore.publishLimitGb(limitGb);
  }

  private static normalizeMode(raw: string): AutoCacheMode {
    if (raw === 'off' || raw === 'always' || raw === 'wifi_only') {
      return raw;
    }
    return DEFAULT_AUTO_CACHE_MODE;
  }

  private static normalizeLimitGb(raw: number): CacheLimitGb {
    if (raw === 1 || raw === 2 || raw === 5 || raw === 10) {
      return raw;
    }
    return DEFAULT_LIMIT_GB;
  }
}
