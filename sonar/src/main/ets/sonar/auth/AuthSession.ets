import { connection } from '@kit.NetworkKit';
import { SubsonicApiError } from '../api/SubsonicTypes';
import { SubsonicClient } from '../api/SubsonicClient';
import { AuthStore, SavedAuth } from './AuthStore';
import { Logger } from '../common/Logger';
import { NetworkStatus } from '../common/NetworkStatus';
import { PlaybackSession } from '../playback/PlaybackSession';

const LOCAL_PROBE_INTERVAL_MS: number = 300_000;
const WIFI_TRIGGER_DEBOUNCE_MS: number = 5_000;

export class AuthSession {
  private static localProbeTimerId: number | null = null;
  private static isProbingLocal: boolean = false;
  private static lastWifiTriggerMs: number = 0;
  private static netConnection = connection.createNetConnection();
  private static readonly netRegisterCallback: () => void = () => {};
  private static readonly netCapabilitiesCallback = (info: connection.NetCapabilityInfo): void => {
    AuthSession.refreshNetworkType();
    const now: number = Date.now();
    if (now - AuthSession.lastWifiTriggerMs < WIFI_TRIGGER_DEBOUNCE_MS) {
      return;
    }
    const hasWifi: boolean = info.netCap.bearerTypes.includes(connection.NetBearType.BEARER_WIFI);
    if (hasWifi) {
      AuthSession.lastWifiTriggerMs = now;
      Logger.info('AuthSession', 'wifi became available, trigger local probe');
      void AuthSession.probeAndSwitchToLocalIfAvailable('wifi');
    }
  };

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

  /**
   * 统一的登录态生效入口：应用登录态、启动本地探测调度器并立即触发一次探测。
   * 全新登录与冷启动恢复都走这里，保证 WIFI/定时探测立即生效。
   */
  static onLoggedIn(auth: SavedAuth, trigger: string = 'login'): void {
    AuthSession.applyLoggedIn(auth);
    AuthSession.startLocalProbeScheduler();
    void AuthSession.probeAndSwitchToLocalIfAvailable(trigger);
  }

  static async restoreFromStore(): Promise<void> {
    await AuthStore.getInstance().ensureReady();
    const creds: SavedAuth | null = AuthStore.getInstance().getCredentials();
    if (creds === null) {
      AuthSession.stopLocalProbeScheduler();
      await PlaybackSession.release();
      AuthSession.applyLoggedOut();
      return;
    }
    AuthSession.onLoggedIn(creds, 'startup');
  }

  static async logout(): Promise<void> {
    AuthSession.stopLocalProbeScheduler();
    await PlaybackSession.release();
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

  private static shouldProbeLocal(): boolean {
    const store: AuthStore = AuthStore.getInstance();
    const creds: SavedAuth | null = store.getCredentials();
    if (creds === null) {
      return false;
    }
    if (!store.hasLocalServerUrl()) {
      return false;
    }
    if (creds.activeEndpoint !== 'remote') {
      return false;
    }
    if (!NetworkStatus.isOnWifi()) {
      return false;
    }
    return true;
  }

  static startLocalProbeScheduler(): void {
    if (AuthSession.localProbeTimerId !== null) {
      return;
    }
    AuthSession.localProbeTimerId = setInterval(() => {
      Logger.info('AuthSession', 'periodic local probe tick');
      void AuthSession.probeAndSwitchToLocalIfAvailable('periodic');
    }, LOCAL_PROBE_INTERVAL_MS);
    AuthSession.netConnection.on('netCapabilitiesChange', AuthSession.netCapabilitiesCallback);
    AuthSession.netConnection.register(AuthSession.netRegisterCallback);
    AuthSession.refreshNetworkType();
    Logger.info('AuthSession', 'local probe scheduler started');
  }

  static stopLocalProbeScheduler(): void {
    if (AuthSession.localProbeTimerId !== null) {
      clearInterval(AuthSession.localProbeTimerId);
      AuthSession.localProbeTimerId = null;
    }
    AuthSession.netConnection.unregister(AuthSession.netRegisterCallback);
    Logger.info('AuthSession', 'local probe scheduler stopped');
  }

  static async probeAndSwitchToLocalIfAvailable(trigger: string = 'manual'): Promise<void> {
    if (AuthSession.isProbingLocal) {
      Logger.info('AuthSession', `skip local probe(${trigger}): probe already running`);
      return;
    }
    if (!AuthSession.shouldProbeLocal()) {
      Logger.info('AuthSession', `skip local probe(${trigger}): condition not met`);
      return;
    }
    AuthSession.isProbingLocal = true;
    const store: AuthStore = AuthStore.getInstance();
    const creds: SavedAuth | null = store.getCredentials();
    if (creds === null) {
      AuthSession.isProbingLocal = false;
      return;
    }
    try {
      Logger.info('AuthSession', `start probing local endpoint(${trigger})`);
      await SubsonicClient.getInstance().pingEndpoint(creds, 'local', false);
      await store.setActiveEndpoint('local');
      creds.activeEndpoint = 'local';
      AuthSession.applyLoggedIn(creds);
      Logger.info('AuthSession', `local endpoint is available(${trigger}), switched to local`);
    } catch (err) {
      await store.setActiveEndpoint('remote');
      creds.activeEndpoint = 'remote';
      AuthSession.applyLoggedIn(creds);
      const localUrl: string = AuthStore.resolveEndpointUrl(creds, 'local');
      if (err instanceof SubsonicApiError) {
        Logger.warn('AuthSession',
          `local endpoint probe failed(${trigger}), code=${err.code}, msg=${err.message}, url=${localUrl}`);
      } else {
        Logger.warn('AuthSession',
          `local endpoint probe failed(${trigger}), msg=${(err as Error).message}, url=${localUrl}`);
      }
    } finally {
      AuthSession.isProbingLocal = false;
    }
  }
}
