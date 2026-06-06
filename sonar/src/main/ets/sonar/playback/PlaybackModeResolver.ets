import { Song } from '../api/SubsonicTypes';
import { PlaybackMode } from './PlaybackSnapshot';

export function resolveNextIndex(
  queue: Song[],
  currentIndex: number,
  mode: PlaybackMode,
  manual: boolean
): number {
  const queueSize: number = queue.length;
  if (queueSize <= 1) {
    return 0;
  }
  if (mode === 'random') {
    let candidate: number = Math.floor(Math.random() * queueSize);
    if (candidate === currentIndex) {
      candidate = (candidate + 1) % queueSize;
    }
    return candidate;
  }
  if (!manual && mode === 'singleLoop') {
    return currentIndex;
  }
  let nextIndex: number = currentIndex + 1;
  if (nextIndex >= queueSize) {
    nextIndex = 0;
  }
  return nextIndex;
}

export function resolvePreviousIndex(queue: Song[], currentIndex: number): number {
  const queueSize: number = queue.length;
  if (queueSize <= 1) {
    return 0;
  }
  let prevIndex: number = currentIndex - 1;
  if (prevIndex < 0) {
    prevIndex = queueSize - 1;
  }
  return prevIndex;
}
