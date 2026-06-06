import { Logger } from '../common/Logger';

/** 切网 / 续播排查：统一 [music-debug] info，hilog 过滤关键字 music-debug */
export class MusicDebug {
  static log(step: string, detail: string): void {
    Logger.info('music-debug', `[music-debug] ${step} | ${detail}`);
  }

  static urlHost(url: string): string {
    const start: number = url.indexOf('://');
    if (start < 0) {
      return url.length > 48 ? `${url.substring(0, 48)}…` : url;
    }
    const rest: string = url.substring(start + 3);
    const slash: number = rest.indexOf('/');
    const host: string = slash >= 0 ? rest.substring(0, slash) : rest;
    return host.length > 48 ? `${host.substring(0, 48)}…` : host;
  }
}
