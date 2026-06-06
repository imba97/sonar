import { SubsonicApiError, SubsonicEnvelope } from '../../api/SubsonicTypes';

export class SubsonicResponseParser {
  static parseEnvelope<T extends SubsonicEnvelope>(text: string): T {
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

  static isRetryableError(err: SubsonicApiError): boolean {
    if (err.code === 0) {
      return true;
    }
    if (err.code >= 500 && err.code < 600) {
      return true;
    }
    return false;
  }

  static isAuthError(err: SubsonicApiError): boolean {
    return err.code === 40 || err.code === 41;
  }

  static shouldFallbackFromLocal(err: SubsonicApiError): boolean {
    if (SubsonicResponseParser.isAuthError(err)) {
      return false;
    }
    return SubsonicResponseParser.isRetryableError(err);
  }
}
