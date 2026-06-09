import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';

const PBKDF2_ITERATIONS: number = 10000;
const KEY_SIZE_BYTES: number = 16;
const SALT_SIZE: number = 16;
const IV_SIZE: number = 12;

export interface ConfigEncryptedBlob {
  salt: Uint8Array;
  iv: Uint8Array;
  tag: Uint8Array;
  cipher: Uint8Array;
}

function stringToUtf8Bytes(str: string): Uint8Array {
  return new Uint8Array(buffer.from(str, 'utf-8').buffer);
}

function generateRandomBytes(len: number): Uint8Array {
  const rand = cryptoFramework.createRandom();
  const blob = rand.generateRandomSync(len);
  return blob.data;
}

function buildGcmParams(iv: Uint8Array, authTag: Uint8Array): cryptoFramework.GcmParamsSpec {
  const aadBlob: cryptoFramework.DataBlob = { data: new Uint8Array(0) };
  const ivBlob: cryptoFramework.DataBlob = { data: iv };
  const tagBlob: cryptoFramework.DataBlob = { data: authTag };
  return {
    iv: ivBlob,
    aad: aadBlob,
    authTag: tagBlob,
    algName: 'GcmParamsSpec'
  };
}

async function deriveAes128Key(password: string, salt: Uint8Array): Promise<cryptoFramework.SymKey> {
  const spec: cryptoFramework.PBKDF2Spec = {
    algName: 'PBKDF2',
    password: password,
    salt: salt,
    iterations: PBKDF2_ITERATIONS,
    keySize: KEY_SIZE_BYTES
  };
  const kdf = cryptoFramework.createKdf('PBKDF2|SHA256');
  const secret = await kdf.generateSecret(spec);
  const symKeyBlob: cryptoFramework.DataBlob = { data: secret.data };
  const aesGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  return await aesGenerator.convertKey(symKeyBlob);
}

export class ConfigCryptoUtil {
  static async encrypt(plain: Uint8Array, password: string): Promise<ConfigEncryptedBlob> {
    const salt = generateRandomBytes(SALT_SIZE);
    const iv = generateRandomBytes(IV_SIZE);
    const symKey = await deriveAes128Key(password, salt);
    const zeroTag = new Uint8Array(16);
    const gcmParams = buildGcmParams(iv, zeroTag);
    const cipher = cryptoFramework.createCipher('AES128|GCM|PKCS7');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams);
    const plainBlob: cryptoFramework.DataBlob = { data: plain };
    const encryptUpdate = await cipher.update(plainBlob);
    const authTagBlob = await cipher.doFinal(null);
    if (authTagBlob === null || authTagBlob.data === undefined) {
      throw new Error('AES-GCM encrypt: missing auth tag');
    }
    if (encryptUpdate === null || encryptUpdate.data === undefined) {
      throw new Error('AES-GCM encrypt: missing ciphertext');
    }
    return {
      salt,
      iv,
      tag: authTagBlob.data,
      cipher: encryptUpdate.data
    };
  }

  static async decrypt(
    cipher: Uint8Array,
    password: string,
    salt: Uint8Array,
    iv: Uint8Array,
    tag: Uint8Array
  ): Promise<Uint8Array> {
    const symKey = await deriveAes128Key(password, salt);
    const gcmParams = buildGcmParams(iv, tag);
    const decoder = cryptoFramework.createCipher('AES128|GCM|PKCS7');
    await decoder.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams);
    const cipherBlob: cryptoFramework.DataBlob = { data: cipher };
    const decryptUpdate = await decoder.update(cipherBlob);
    await decoder.doFinal(null);
    if (decryptUpdate === null || decryptUpdate.data === undefined) {
      throw new Error('AES-GCM decrypt failed');
    }
    return decryptUpdate.data;
  }

  static utf8ToBytes(str: string): Uint8Array {
    return stringToUtf8Bytes(str);
  }

  static bytesToUtf8(bytes: Uint8Array): string {
    return buffer.from(bytes).toString('utf-8');
  }
}
