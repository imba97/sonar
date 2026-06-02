import { http } from '@kit.NetworkKit';
import { AuthStore, EndpointType, SavedAuth } from '../auth/AuthStore';
import { Logger } from '../common/Logger';
import { RandomUtil } from '../crypto/RandomUtil';
import { Md5Util } from '../crypto/Md5Util';
import {
  Album,
  AlbumDetailResponse,
  AlbumListResponse,
  Artist,
  ArtistIndex,
  ArtistsResponse,
  SearchResponse,
  Song,
  SubsonicApiError,
  SubsonicEnvelope
} from './SubsonicTypes';

const API_VERSION: string = '1.16.1';
const CLIENT_NAME: string = 'sonar';
const MAX_RETRY_ATTEMPTS: number = 3;

interface ArtistIndexContainer {
  index?: ArtistIndex[] | ArtistIndex;
}

interface SingleOrArrayArtistIndex {
  name?: string;
  artist?: Artist[] | Artist;
}

interface RequestRetryPolicy {
  enableRetry: boolean;
  maxAttempts: number;
}

export class SubsonicClient {
  private static instance: SubsonicClient | null = null;
  private static defaultRetryEnabled: boolean = true;
  private static defaultRetryMaxAttempts: number = MAX_RETRY_ATTEMPTS;

  private constructor() {
  }

  static normalizeServerUrl(rawUrl: string): string {
    const trimmed: string = rawUrl.trim();
    if (trimmed.length === 0) {
      throw new SubsonicApiError(-2, '服务器地址不能为空');
    }
    const matched: RegExpMatchArray | null = trimmed.match(/^(https?):\/\/([^/\s]+)(\/[^\s]*)?$/i);
    if (matched === null) {
      throw new SubsonicApiError(-2, '服务器地址格式不正确，请使用 http(s)://host[:port][/path]');
    }
    const normalizedPath: string = (matched[3] ?? '').replace(/\/+$/, '');
    return `${matched[1].toLowerCase()}://${matched[2]}${normalizedPath}`;
  }

  static toArray<T>(value: T | T[] | undefined): T[] {
    if (value === undefined) {
      return [];
    }
    if (Array.isArray(value)) {
      return value;
    }
    return [value];
  }

  static getInstance(): SubsonicClient {
    if (SubsonicClient.instance === null) {
      SubsonicClient.instance = new SubsonicClient();
    }
    return SubsonicClient.instance;
  }

  static configureRetryPolicy(enableRetry: boolean, maxAttempts: number = MAX_RETRY_ATTEMPTS): void {
    SubsonicClient.defaultRetryEnabled = enableRetry;
    SubsonicClient.defaultRetryMaxAttempts = maxAttempts > 0 ? maxAttempts : 1;
  }

  /**
   * 计算最终请求 URL（含 u/v/c/f + 可选 t/s + 业务参数）。
   * extraParams 为扁平字符串数组：[key1, value1, key2, value2, ...]
   * 当未传入 auth 时，从 AuthStore 读取已保存凭据。
   */
  private buildUrl(endpoint: string, extraParams: string[] = [],
    auth?: SavedAuth, targetEndpoint?: EndpointType): string {
    const a: SavedAuth | null = auth ?? AuthStore.getInstance().getCredentials();
    if (a === null) {
      throw new SubsonicApiError(-3, 'Not logged in');
    }
    const resolvedEndpoint: EndpointType = targetEndpoint ?? a.activeEndpoint;
    const baseSource: string = AuthStore.resolveEndpointUrl(a, resolvedEndpoint);
    const base: string = SubsonicClient.normalizeServerUrl(baseSource);
    const allParams: string[] = [
      'u=' + encodeURIComponent(a.username),
      'v=' + encodeURIComponent(API_VERSION),
      'c=' + encodeURIComponent(CLIENT_NAME),
      'f=json',
      't=' + encodeURIComponent(a.token),
      's=' + encodeURIComponent(a.salt)
    ];
    if (a.authMode !== undefined && a.authMode !== 'subsonicToken') {
      throw new SubsonicApiError(-4, `Unsupported auth mode: ${a.authMode}`);
    }
    for (let i: number = 0; i < extraParams.length; i += 2) {
      const k: string = encodeURIComponent(extraParams[i]);
      const v: string = encodeURIComponent(extraParams[i + 1]);
      allParams.push(k + '=' + v);
    }
    return `${base}/rest/${endpoint}?${allParams.join('&')}`;
  }

  private async requestOnce<T extends SubsonicEnvelope>(url: string): Promise<T> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (resp.responseCode !== http.ResponseCode.OK) {
        throw new SubsonicApiError(resp.responseCode, `HTTP ${resp.responseCode}`);
      }
      return SubsonicClient.parseEnvelope<T>(resp.result as string);
    } catch (err) {
      if (err instanceof SubsonicApiError) {
        throw new SubsonicApiError(err.code, err.message);
      }
      throw new SubsonicApiError(0, (err as Error).message);
    } finally {
      req.destroy();
    }
  }

  private static isRetryableError(err: SubsonicApiError): boolean {
    if (err.code === 0) {
      return true;
    }
    if (err.code >= 500 && err.code < 600) {
      return true;
    }
    return false;
  }

  private async requestWithRetry<T extends SubsonicEnvelope>(url: string,
    policy?: RequestRetryPolicy): Promise<T> {
    const effectivePolicy: RequestRetryPolicy = policy ?? {
      enableRetry: SubsonicClient.defaultRetryEnabled,
      maxAttempts: SubsonicClient.defaultRetryMaxAttempts
    };
    if (!effectivePolicy.enableRetry) {
      return await this.requestOnce<T>(url);
    }
    const maxAttempts: number = effectivePolicy.maxAttempts;
    let attempt: number = 1;
    while (true) {
      try {
        return await this.requestOnce<T>(url);
      } catch (err) {
        const apiErr: SubsonicApiError = err as SubsonicApiError;
        if (attempt >= maxAttempts || !SubsonicClient.isRetryableError(apiErr)) {
          throw apiErr;
        }
        Logger.warn('SubsonicClient', `request retry ${attempt}/${maxAttempts}: ${apiErr.message}`);
        attempt++;
      }
    }
  }

  private static syncActiveServerToAppStorage(auth: SavedAuth, endpoint: EndpointType): void {
    const activeServer: string = AuthStore.resolveEndpointUrl(auth, endpoint);
    AppStorage.setOrCreate<string>('loggedInServer', activeServer);
    AppStorage.setOrCreate<string>('loggedInEndpoint', endpoint);
  }

  private async requestByAuth<T extends SubsonicEnvelope>(endpoint: string,
    extraParams: string[] = [], auth?: SavedAuth, policy?: RequestRetryPolicy): Promise<T> {
    const credentials: SavedAuth | null = auth ?? AuthStore.getInstance().getCredentials();
    if (credentials === null) {
      throw new SubsonicApiError(-3, 'Not logged in');
    }

    const preferredEndpoint: EndpointType = credentials.activeEndpoint;
    const preferredUrl: string = this.buildUrl(endpoint, extraParams, credentials, preferredEndpoint);
    try {
      return await this.requestWithRetry<T>(preferredUrl, policy);
    } catch (err) {
      const apiErr: SubsonicApiError = err as SubsonicApiError;
      const shouldFallbackToRemote: boolean =
        preferredEndpoint === 'local' &&
        credentials.localServerUrl !== undefined &&
        SubsonicClient.isRetryableError(apiErr);
      if (!shouldFallbackToRemote) {
        throw apiErr;
      }

      Logger.warn('SubsonicClient', 'local endpoint failed, fallback to remote endpoint');
      await AuthStore.getInstance().setActiveEndpoint('remote');
      credentials.activeEndpoint = 'remote';
      SubsonicClient.syncActiveServerToAppStorage(credentials, 'remote');
      const remoteUrl: string = this.buildUrl(endpoint, extraParams, credentials, 'remote');
      return await this.requestWithRetry<T>(remoteUrl, policy);
    }
  }

  private static parseEnvelope<T extends SubsonicEnvelope>(text: string): T {
    const raw: Object = JSON.parse(text);
    const entries: [string, Object][] = Object.entries(raw);
    let env: T | undefined;
    for (let i: number = 0; i < entries.length; i++) {
      if (entries[i][0] === 'subsonic-response') {
        env = entries[i][1] as T;
      }
    }
    if (env === undefined) {
      throw new SubsonicApiError(-1, 'Missing subsonic-response wrapper');
    }
    if (env.status === 'failed') {
      let errCode: number = -1;
      let errMsg: string = 'Unknown error';
      if (env.error !== undefined) {
        errCode = env.error.code;
        errMsg = env.error.message;
      }
      throw new SubsonicApiError(errCode, errMsg);
    }
    return env;
  }

  /**
   * 组装登录凭据：生成 salt/token 并构造 SavedAuth，不发起任何请求。
   * 由调用方使用 pingEndpoint 分别探测远程/本地后决定 activeEndpoint 并持久化。
   */
  static async buildLoginAuth(remoteUrl: string, localUrl: string | undefined,
    username: string, password: string): Promise<SavedAuth> {
    const salt: string = RandomUtil.generateSalt();
    const token: string = await Md5Util.md5Hex(password + salt);
    const loginAuth: SavedAuth = {
      remoteServerUrl: SubsonicClient.normalizeServerUrl(remoteUrl),
      localServerUrl: localUrl !== undefined ? SubsonicClient.normalizeServerUrl(localUrl) : undefined,
      activeEndpoint: 'remote',
      username: username,
      salt,
      token,
      authMode: 'subsonicToken'
    };
    return loginAuth;
  }

  async pingEndpoint(auth: SavedAuth, endpoint: EndpointType, enableRetry: boolean = true): Promise<void> {
    const retryPolicy: RequestRetryPolicy = {
      enableRetry,
      maxAttempts: MAX_RETRY_ATTEMPTS
    };
    const url: string = this.buildUrl('ping.view', [], auth, endpoint);
    await this.requestWithRetry<SubsonicEnvelope>(url, retryPolicy);
  }

  async getArtists(): Promise<ArtistsResponse> {
    const resp: ArtistsResponse = await this.requestByAuth<ArtistsResponse>('getArtists.view');
    const artistsBox: ArtistIndexContainer = resp.artists as ArtistIndexContainer;
    const indexValue: ArtistIndex[] | ArtistIndex | undefined = artistsBox.index;
    const normalizedIndex: ArtistIndex[] = SubsonicClient.toArray<ArtistIndex>(indexValue);
    for (let i: number = 0; i < normalizedIndex.length; i++) {
      const item: SingleOrArrayArtistIndex = normalizedIndex[i] as SingleOrArrayArtistIndex;
      const artists: Artist[] | Artist | undefined = item.artist;
      item.artist = SubsonicClient.toArray<Artist>(artists);
      if (item.name === undefined) {
        item.name = '';
      }
    }
    resp.artists.index = normalizedIndex;
    return resp;
  }

  async getAlbumList2(type: string = 'newest', size: number = 60, offset: number = 0): Promise<AlbumListResponse> {
    const resp: AlbumListResponse =
      await this.requestByAuth<AlbumListResponse>('getAlbumList2.view',
        ['type', type, 'size', String(size), 'offset', String(offset)]);
    const rawAlbums: Album[] | Album | undefined = resp.albumList2.album as Album[] | Album | undefined;
    resp.albumList2.album = SubsonicClient.toArray<Album>(rawAlbums);
    return resp;
  }

  async getAlbum(id: string): Promise<AlbumDetailResponse> {
    const resp: AlbumDetailResponse = await this.requestByAuth<AlbumDetailResponse>('getAlbum.view', ['id', id]);
    const rawSongs: Song[] | Song | undefined = resp.album.song as Song[] | Song | undefined;
    resp.album.song = SubsonicClient.toArray<Song>(rawSongs);
    return resp;
  }

  async search3(query: string, artistCount: number = 20,
    albumCount: number = 20, songCount: number = 20): Promise<SearchResponse> {
    const resp: SearchResponse = await this.requestByAuth<SearchResponse>('search3.view', [
      'query', query,
      'artistCount', String(artistCount),
      'albumCount', String(albumCount),
      'songCount', String(songCount)
    ]);
    if (resp.searchResult3 !== undefined) {
      resp.searchResult3.artist = SubsonicClient.toArray(resp.searchResult3.artist);
      resp.searchResult3.album = SubsonicClient.toArray(resp.searchResult3.album);
      resp.searchResult3.song = SubsonicClient.toArray(resp.searchResult3.song);
    }
    return resp;
  }

  getCoverArtUrl(coverArtId: string, size: number = 300): string {
    return this.buildUrl('getCoverArt.view', ['id', coverArtId, 'size', String(size)]);
  }

  getStreamUrl(songId: string, maxBitRate: number = 0): string {
    const params: string[] = ['id', songId];
    if (maxBitRate > 0) {
      params.push('maxBitRate', String(maxBitRate));
    }
    return this.buildUrl('stream.view', params);
  }

  getScrobbleUrl(songId: string): string {
    return this.buildUrl('scrobble.view', ['id', songId]);
  }

  private static normalizeEpochMs(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return Date.now();
    }
    return Math.floor(value);
  }

  private static normalizePositionSeconds(positionMs: number): number {
    if (!Number.isFinite(positionMs) || positionMs <= 0) {
      return 0;
    }
    return Math.floor(positionMs / 1000);
  }

  async reportNowPlaying(songId: string, positionMs: number = 0): Promise<void> {
    const positionSec: number = SubsonicClient.normalizePositionSeconds(positionMs);
    const params: string[] = [
      'id', songId,
      'submission', 'false',
      'time', '0'
    ];
    if (positionSec > 0) {
      params.push('position', String(positionSec));
    }
    Logger.debug('SubsonicClient',
      `scrobble nowPlaying id=${songId} positionSec=${positionSec}`);
    try {
      await this.requestByAuth<SubsonicEnvelope>('scrobble.view', params);
    } catch (err) {
      if (positionSec <= 0) {
        throw new Error((err as Error).message);
      }
      Logger.warn('SubsonicClient',
        `scrobble nowPlaying with position failed, fallback standard call: ${(err as Error).message}`);
      await this.requestByAuth<SubsonicEnvelope>('scrobble.view', [
        'id', songId,
        'submission', 'false',
        'time', '0'
      ]);
    }
  }

  async submitScrobble(songId: string, listenedAtEpochMs: number = Date.now()): Promise<void> {
    const normalizedEpochMs: number = SubsonicClient.normalizeEpochMs(listenedAtEpochMs);
    Logger.debug('SubsonicClient',
      `scrobble submission id=${songId} time=${normalizedEpochMs}`);
    await this.requestByAuth<SubsonicEnvelope>('scrobble.view', [
      'id', songId,
      'submission', 'true',
      'time', String(normalizedEpochMs)
    ]);
  }
}
