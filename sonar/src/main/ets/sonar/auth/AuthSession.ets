import { SubsonicApiError } from '../api/SubsonicTypes';
import { AuthStore, SavedAuth } from './AuthStore';
import { Logger } from '../common/Logger';
import { NetworkStatus } from '../common/NetworkStatus';
import { EndpointRouter } from '../network/routing/EndpointRouter';
import { NetworkCoordinator } from '../network/coordinator/NetworkCoordinator';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackPipeline } from '../playback/pipeline/PlaybackPipeline';

export class AuthSession {
  static refreshNetworkType(): void {
    AppStorage.setOrCreate<string>('networkType', NetworkStatus.getNetworkType());
  }

  static applyLoggedIn(auth: SavedAuth): void {
    const activeServer: string = AuthStore.resolveEndpointUrl(auth, auth.activeEndpoint);
    AppStorage.setOrCreate<boolean>('isLoggedIn', true);
    AppStorage.setOrCreate<string>('loggedInServer', activeServer);
    AppStorage.setOrCreate<string>('loggedInUser', auth.username);
    AppStorage.setOrCreate<string>('loggedInEndpoint', auth.activeEndpoint);
  }

  static applyLoggedOut(): void {
    AppStorage.setOrCreate<boolean>('isLoggedIn', false);
    AppStorage.setOrCreate<string>('loggedInServer', '');
    AppStorage.setOrCreate<string>('loggedInUser', '');
    AppStorage.setOrCreate<string>('loggedInEndpoint', 'remote');
  }

  static onLoggedIn(auth: SavedAuth, _trigger: string = 'login'): void {
    AuthSession.applyLoggedIn(auth);
    EndpointRouter.start();
    NetworkCoordinator.init();
    PlaybackPipeline.initialize();
    void EndpointRouter.bootstrap(auth);
  }

  static async restoreFromStore(): Promise<void> {
    await AuthStore.getInstance().ensureReady();
    const creds: SavedAuth | null = AuthStore.getInstance().getCredentials();
    if (creds === null) {
      EndpointRouter.stop();
      NetworkCoordinator.shutdown();
      await PlaybackService.release();
      AuthSession.applyLoggedOut();
      return;
    }
    AuthSession.onLoggedIn(creds, 'startup');
  }

  static async logout(): Promise<void> {
    EndpointRouter.stop();
    NetworkCoordinator.shutdown();
    await PlaybackService.release();
    await AuthStore.getInstance().clear();
    AuthSession.applyLoggedOut();
  }

  static async invalidateIfAuthError(err: Error): Promise<boolean> {
    if (err instanceof SubsonicApiError && (err.code === 40 || err.code === 41)) {
      await AuthSession.logout();
      return true;
    }
    return false;
  }
}
