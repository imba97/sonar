import { PlaybackSnapshot } from './PlaybackSnapshot';

const STORAGE_KEY: string = 'playback';

export type PlaybackStoreListener = (snapshot: PlaybackSnapshot) => void;

export class PlaybackStore {
  private static listeners: PlaybackStoreListener[] = [];

  static init(snapshot: PlaybackSnapshot = PlaybackSnapshot.idle()): void {
    AppStorage.setOrCreate<PlaybackSnapshot>(STORAGE_KEY, snapshot);
  }

  static get(): PlaybackSnapshot {
    const value: PlaybackSnapshot | undefined = AppStorage.get<PlaybackSnapshot>(STORAGE_KEY);
    if (value === undefined) {
      return PlaybackSnapshot.idle();
    }
    return value;
  }

  static publish(snapshot: PlaybackSnapshot): void {
    AppStorage.setOrCreate<PlaybackSnapshot>(STORAGE_KEY, snapshot);
    PlaybackStore.notify(snapshot);
  }

  static subscribe(listener: PlaybackStoreListener): void {
    PlaybackStore.listeners.push(listener);
  }

  static unsubscribe(listener: PlaybackStoreListener): void {
    const next: PlaybackStoreListener[] = [];
    for (let i: number = 0; i < PlaybackStore.listeners.length; i++) {
      if (PlaybackStore.listeners[i] !== listener) {
        next.push(PlaybackStore.listeners[i]);
      }
    }
    PlaybackStore.listeners = next;
  }

  private static notify(snapshot: PlaybackSnapshot): void {
    for (let i: number = 0; i < PlaybackStore.listeners.length; i++) {
      PlaybackStore.listeners[i](snapshot);
    }
  }
}
