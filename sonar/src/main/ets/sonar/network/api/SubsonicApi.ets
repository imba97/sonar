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
} from '../../api/SubsonicTypes';
import { EndpointType, SavedAuth } from '../../auth/AuthStore';
import { Logger } from '../../common/Logger';
import { RandomUtil } from '../../crypto/RandomUtil';
import { Md5Util } from '../../crypto/Md5Util';
import { AuthContext } from '../auth/AuthContext';
import { SubsonicResponseParser } from './SubsonicResponseParser';
import { SubsonicUrlUtil } from './SubsonicUrlUtil';
import { HttpTransport } from '../transport/HttpTransport';
import { EndpointRouter } from '../routing/EndpointRouter';

interface ArtistIndexContainer {
  index?: ArtistIndex[] | ArtistIndex;
}

interface SingleOrArrayArtistIndex {
  name?: string;
  artist?: Artist[] | Artist;
}

export class SubsonicApi {
  static toArray<T>(value: T | T[] | undefined): T[] {
    if (value === undefined) {
      return [];
    }
    if (Array.isArray(value)) {
      return value;
    }
    return [value];
  }

  static async buildLoginAuth(remoteUrl: string, localUrl: string | undefined,
    username: string, password: string): Promise<SavedAuth> {
    const salt: string = RandomUtil.generateSalt();
    const token: string = await Md5Util.md5Hex(password + salt);
    return {
      remoteServerUrl: SubsonicUrlUtil.normalizeServerUrl(remoteUrl),
      localServerUrl: localUrl !== undefined ? SubsonicUrlUtil.normalizeServerUrl(localUrl) : undefined,
      activeEndpoint: 'remote',
      username,
      salt,
      token,
      authMode: 'subsonicToken'
    };
  }

  static async pingEndpoint(auth: SavedAuth, endpoint: EndpointType): Promise<void> {
    const url: string = AuthContext.buildRestUrl('ping.view', [], auth, endpoint);
    await HttpTransport.probeRest(url);
  }

  private static async requestEnvelope<T extends SubsonicEnvelope>(api: string,
    extraParams: string[] = []): Promise<T> {
    const text: string = await HttpTransport.requestWithFallback({
      buildUrl: (ep: EndpointType): string => AuthContext.buildRestUrl(api, extraParams, undefined, ep),
      profile: 'json'
    });
    return SubsonicResponseParser.parseEnvelope<T>(text);
  }

  static async getArtists(): Promise<ArtistsResponse> {
    const resp: ArtistsResponse = await SubsonicApi.requestEnvelope<ArtistsResponse>('getArtists.view');
    const artistsBox: ArtistIndexContainer = resp.artists as ArtistIndexContainer;
    const indexValue: ArtistIndex[] | ArtistIndex | undefined = artistsBox.index;
    const normalizedIndex: ArtistIndex[] = SubsonicApi.toArray<ArtistIndex>(indexValue);
    for (let i: number = 0; i < normalizedIndex.length; i++) {
      const item: SingleOrArrayArtistIndex = normalizedIndex[i] as SingleOrArrayArtistIndex;
      const artists: Artist[] | Artist | undefined = item.artist;
      item.artist = SubsonicApi.toArray<Artist>(artists);
      if (item.name === undefined) {
        item.name = '';
      }
    }
    resp.artists.index = normalizedIndex;
    return resp;
  }

  static async getAlbumList2(type: string = 'newest', size: number = 60,
    offset: number = 0): Promise<AlbumListResponse> {
    const resp: AlbumListResponse = await SubsonicApi.requestEnvelope<AlbumListResponse>('getAlbumList2.view', [
      'type', type, 'size', String(size), 'offset', String(offset)
    ]);
    const rawAlbums: Album[] | Album | undefined = resp.albumList2.album as Album[] | Album | undefined;
    resp.albumList2.album = SubsonicApi.toArray<Album>(rawAlbums);
    return resp;
  }

  static async getAlbum(id: string): Promise<AlbumDetailResponse> {
    const resp: AlbumDetailResponse =
      await SubsonicApi.requestEnvelope<AlbumDetailResponse>('getAlbum.view', ['id', id]);
    const rawSongs: Song[] | Song | undefined = resp.album.song as Song[] | Song | undefined;
    resp.album.song = SubsonicApi.toArray<Song>(rawSongs);
    return resp;
  }

  static async search3(query: string, artistCount: number = 20,
    albumCount: number = 20, songCount: number = 20): Promise<SearchResponse> {
    const resp: SearchResponse = await SubsonicApi.requestEnvelope<SearchResponse>('search3.view', [
      'query', query,
      'artistCount', String(artistCount),
      'albumCount', String(albumCount),
      'songCount', String(songCount)
    ]);
    if (resp.searchResult3 !== undefined) {
      resp.searchResult3.artist = SubsonicApi.toArray(resp.searchResult3.artist);
      resp.searchResult3.album = SubsonicApi.toArray(resp.searchResult3.album);
      resp.searchResult3.song = SubsonicApi.toArray(resp.searchResult3.song);
    }
    return resp;
  }

  static async reportNowPlaying(songId: string, positionMs: number = 0): Promise<void> {
    const positionSec: number = SubsonicApi.normalizePositionSeconds(positionMs);
    const params: string[] = ['id', songId, 'submission', 'false', 'time', '0'];
    if (positionSec > 0) {
      params.push('position', String(positionSec));
    }
    Logger.debug('SubsonicApi', `scrobble nowPlaying id=${songId} positionSec=${positionSec}`);
    try {
      await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', params);
    } catch (err) {
      if (positionSec <= 0) {
        throw new Error((err as Error).message);
      }
      Logger.warn('SubsonicApi',
        `scrobble nowPlaying with position failed, fallback standard call: ${(err as Error).message}`);
      await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', [
        'id', songId, 'submission', 'false', 'time', '0'
      ]);
    }
  }

  static async submitScrobble(songId: string, listenedAtEpochMs: number = Date.now()): Promise<void> {
    const normalizedEpochMs: number = SubsonicApi.normalizeEpochMs(listenedAtEpochMs);
    Logger.debug('SubsonicApi', `scrobble submission id=${songId} time=${normalizedEpochMs}`);
    await SubsonicApi.requestEnvelope<SubsonicEnvelope>('scrobble.view', [
      'id', songId, 'submission', 'true', 'time', String(normalizedEpochMs)
    ]);
  }

  static async validateLoginRemote(auth: SavedAuth): Promise<void> {
    await EndpointRouter.validateRemoteReachable(auth);
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
}
