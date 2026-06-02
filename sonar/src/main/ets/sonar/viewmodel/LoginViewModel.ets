import { SubsonicClient } from '../api/SubsonicClient';
import { SubsonicApiError } from '../api/SubsonicTypes';
import { AuthStore, RememberedLoginInfo, SavedAuth } from '../auth/AuthStore';
import { AuthSession } from '../auth/AuthSession';
import { NetworkStatus } from '../common/NetworkStatus';

@Observed
export class LoginViewModel {
  serverUrl: string = '';
  localServerUrl: string = '';
  username: string = '';
  password: string = '';
  isLoading: boolean = false;
  errorMessage: string = '';
  private rememberedLoaded: boolean = false;

  private static describeError(err: SubsonicApiError): string {
    switch (err.code) {
      case -2:
        return err.message;
      case 0:
        return '无法连接服务器，请检查地址与网络';
      case 10:
        return '请求参数不完整或格式错误 (code 10)';
      case 40:
        return '用户名或密码错误 (code 40)';
      case 41:
        return '该账户不支持 token 登录，请改用支持的账号 (code 41)';
      case 50:
        return '当前账户没有执行该操作的权限 (code 50)';
      default:
        return `服务器错误 (${err.code}): ${err.message}`;
    }
  }

  async restoreRememberedInputs(): Promise<void> {
    if (this.rememberedLoaded) {
      return;
    }
    const info: RememberedLoginInfo = await AuthStore.getInstance().getRememberedLoginInfo();
    if (this.serverUrl.length === 0) {
      this.serverUrl = info.remoteServerUrl;
    }
    if (this.localServerUrl.length === 0) {
      this.localServerUrl = info.localServerUrl;
    }
    if (this.username.length === 0) {
      this.username = info.username;
    }
    if (this.password.length === 0) {
      this.password = info.password;
    }
    this.rememberedLoaded = true;
  }

  async submit(onSuccess: () => void): Promise<void> {
    if (this.isLoading) {
      return;
    }
    const serverUrlInput: string = this.serverUrl.trim();
    const localServerUrlInput: string = this.localServerUrl.trim();
    const username: string = this.username.trim();
    const password: string = this.password;

    if (serverUrlInput.length === 0) {
      this.errorMessage = '请输入服务器地址';
      return;
    }
    if (username.length === 0) {
      this.errorMessage = '请输入用户名';
      return;
    }
    if (password.length === 0) {
      this.errorMessage = '请输入密码';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    try {
      const serverUrl: string = SubsonicClient.normalizeServerUrl(serverUrlInput);
      const localServerUrl: string | undefined = localServerUrlInput.length > 0 ?
        SubsonicClient.normalizeServerUrl(localServerUrlInput) : undefined;
      const loginAuth: SavedAuth =
        await SubsonicClient.buildLoginAuth(serverUrl, localServerUrl, username, password);
      const client: SubsonicClient = SubsonicClient.getInstance();
      let remoteErr: Error | null = null;
      const tryLocal: boolean = localServerUrl !== undefined && NetworkStatus.isOnWifi();
      const localTask: Promise<boolean> = tryLocal
        ? client.pingEndpoint(loginAuth, 'local', false).then(() => true).catch(() => false)
        : Promise.resolve(false);
      const remoteTask: Promise<boolean> = client.pingEndpoint(loginAuth, 'remote', true)
        .then(() => true).catch((e: Error) => {
          remoteErr = e;
          return false;
        });
      const results: boolean[] = await Promise.all([localTask, remoteTask]);
      if (results[0]) {
        loginAuth.activeEndpoint = 'local';
      } else if (results[1]) {
        loginAuth.activeEndpoint = 'remote';
      } else {
        throw (remoteErr ?? new SubsonicApiError(0, '无法连接服务器，请检查地址与网络'));
      }
      const authStore: AuthStore = AuthStore.getInstance();
      await authStore.save(loginAuth);
      await authStore.rememberLoginInfo({
        remoteServerUrl: serverUrl,
        localServerUrl: localServerUrl ?? '',
        username,
        password
      });
      AuthSession.onLoggedIn(loginAuth);
      onSuccess();
    } catch (err) {
      if (err instanceof SubsonicApiError) {
        this.errorMessage = LoginViewModel.describeError(err);
      } else {
        this.errorMessage = `网络错误: ${(err as Error).message}`;
      }
    } finally {
      this.isLoading = false;
    }
  }
}
