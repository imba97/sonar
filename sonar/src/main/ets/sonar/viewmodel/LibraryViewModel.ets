import { Album } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { AuthSession } from '../auth/AuthSession';

export type LibraryTab = 'newest' | 'artists' | 'random';

@Observed
export class LibraryViewModel {
  tab: LibraryTab = 'newest';
  albums: Album[] = [];
  isLoading: boolean = false;
  errorMessage: string = '';
  authExpired: boolean = false;

  async loadNewest(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    try {
      const resp = await SubsonicClient.getInstance().getAlbumList2('newest', 60);
      this.albums = resp.albumList2.album ?? [];
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      } else {
        this.errorMessage = (err as Error).message;
      }
      this.albums = [];
    } finally {
      this.isLoading = false;
    }
  }

  async loadRandom(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.authExpired = false;
    try {
      const resp = await SubsonicClient.getInstance().getAlbumList2('random', 60);
      this.albums = resp.albumList2.album ?? [];
    } catch (err) {
      const expired: boolean = await AuthSession.invalidateIfAuthError(err as Error);
      if (expired) {
        this.authExpired = true;
        this.errorMessage = '登录已失效，请重新登录';
      } else {
        this.errorMessage = (err as Error).message;
      }
      this.albums = [];
    } finally {
      this.isLoading = false;
    }
  }

  coverUrl(coverArt: string | undefined): string | undefined {
    if (coverArt === undefined || coverArt.length === 0) {
      return undefined;
    }
    return SubsonicClient.getInstance().getCoverArtUrl(coverArt, 300);
  }
}
