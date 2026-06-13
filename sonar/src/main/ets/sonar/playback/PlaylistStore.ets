import { PlaylistSnapshot } from './PlaylistSnapshot';

const STORAGE_KEY: string = 'playlist';

export type PlaylistStoreListener = (snapshot: PlaylistSnapshot) => void;

export class PlaylistStore {
  private static listeners: PlaylistStoreListener[] = [];

  static init(snapshot: PlaylistSnapshot = PlaylistSnapshot.empty()): void {
    AppStorage.setOrCreate<PlaylistSnapshot>(STORAGE_KEY, snapshot);
  }

  static get(): PlaylistSnapshot {
    const value: PlaylistSnapshot | undefined = AppStorage.get<PlaylistSnapshot>(STORAGE_KEY);
    if (value === undefined) {
      return PlaylistSnapshot.empty();
    }
    return value;
  }

  static publish(snapshot: PlaylistSnapshot): void {
    AppStorage.setOrCreate<PlaylistSnapshot>(STORAGE_KEY, snapshot);
    PlaylistStore.notify(snapshot);
  }

  static subscribe(listener: PlaylistStoreListener): void {
    PlaylistStore.listeners.push(listener);
  }

  static unsubscribe(listener: PlaylistStoreListener): void {
    const next: PlaylistStoreListener[] = [];
    for (let i: number = 0; i < PlaylistStore.listeners.length; i++) {
      if (PlaylistStore.listeners[i] !== listener) {
        next.push(PlaylistStore.listeners[i]);
      }
    }
    PlaylistStore.listeners = next;
  }

  private static notify(snapshot: PlaylistSnapshot): void {
    for (let i: number = 0; i < PlaylistStore.listeners.length; i++) {
      PlaylistStore.listeners[i](snapshot);
    }
  }
}
