import { image } from '@kit.ImageKit';
import { CoverCache } from '../../playback/CoverCache';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';

/** 约 60fps 更新角度，便于暂停时冻结当前朝向（animateTo 无法保留中间角度） */
const COVER_ROTATION_TICK_MS: number = 16;

@Component
export struct MiniBarCoverDisc {
  @Prop outerSize: number = UiTokens.FLOATING_TAB_BAR_HEIGHT;
  @Prop coverInset: number = UiTokens.MINI_BAR_BALL_COVER_INSET;
  @StorageLink('playback') @Watch('onPlaybackChange') playback: PlaybackSnapshot = PlaybackSnapshot.idle();

  @State private coverRotateDeg: number = 0;
  @State private coverPixelMap: image.PixelMap | null = null;
  @State private boundCoverArtId: string = '';
  private lastRotationPlaying: boolean = false;
  private lastCoverRevision: number = -1;
  private rotationTimerId: number = -1;

  private innerSize(): number {
    return Math.max(0, this.outerSize - this.coverInset * 2);
  }

  private coverArtId(): string {
    if (this.playback.track === null) {
      return '';
    }
    return this.playback.track.coverArtId;
  }

  aboutToAppear(): void {
    this.lastCoverRevision = this.playback.coverRevision;
    this.syncCoverPixelMap(true);
    this.lastRotationPlaying = this.playback.isPlaying();
    this.applySpinMotion(this.lastRotationPlaying);
  }

  aboutToDisappear(): void {
    this.stopRotationTimer();
  }

  private onPlaybackChange(): void {
    if (this.playback.coverRevision !== this.lastCoverRevision) {
      this.lastCoverRevision = this.playback.coverRevision;
      this.syncCoverPixelMap(true);
    } else {
      this.syncCoverPixelMap(false);
    }

    const playing: boolean = this.playback.isPlaying();
    if (playing === this.lastRotationPlaying) {
      return;
    }
    this.lastRotationPlaying = playing;
    this.applySpinMotion(playing);
  }

  private syncCoverPixelMap(force: boolean): void {
    const coverArtId: string = this.coverArtId();
    const nextMap: image.PixelMap | null = CoverCache.getDisplaySource(coverArtId).pixelMap;
    if (!force && coverArtId === this.boundCoverArtId && nextMap === this.coverPixelMap) {
      return;
    }
    this.boundCoverArtId = coverArtId;
    this.coverPixelMap = nextMap;
    if (nextMap === null && coverArtId.length > 0) {
      void CoverCache.load(coverArtId).then((loaded: image.PixelMap | null) => {
        if (this.coverArtId() !== coverArtId || loaded === null) {
          return;
        }
        this.boundCoverArtId = coverArtId;
        this.coverPixelMap = loaded;
      });
    }
  }

  private rotationStepDeg(): number {
    return 360 * COVER_ROTATION_TICK_MS / UiTokens.DOCK_COVER_ROTATION_DURATION;
  }

  private applySpinMotion(playing: boolean): void {
    if (playing) {
      this.startRotationTimer();
      return;
    }
    this.stopRotationTimer();
  }

  private startRotationTimer(): void {
    if (this.rotationTimerId >= 0) {
      return;
    }
    const stepDeg: number = this.rotationStepDeg();
    this.rotationTimerId = setInterval(() => {
      this.coverRotateDeg = this.coverRotateDeg + stepDeg;
    }, COVER_ROTATION_TICK_MS);
  }

  private stopRotationTimer(): void {
    if (this.rotationTimerId < 0) {
      return;
    }
    clearInterval(this.rotationTimerId);
    this.rotationTimerId = -1;
  }

  @Builder
  private defaultMusicIcon() {
    Image($r('app.media.dock_music_note'))
      .width(this.idleIconSize())
      .height(this.idleIconSize())
      .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      .objectFit(ImageFit.Contain)
  }

  private idleIconSize(): number {
    return this.innerSize() > 0 ? Math.floor(this.innerSize() * 0.52) : 22;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.playback.showMiniPlayer && this.coverPixelMap !== null) {
        Image(this.coverPixelMap)
          .width(this.innerSize())
          .height(this.innerSize())
          .borderRadius(this.innerSize() / 2)
          .objectFit(ImageFit.Cover)
          .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
          .clip(true)
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            angle: this.coverRotateDeg,
            centerX: '50%',
            centerY: '50%'
          })
      } else if (this.playback.showMiniPlayer) {
        this.defaultMusicIcon()
      } else {
        this.defaultMusicIcon()
      }
    }
    .width(this.outerSize)
    .height(this.outerSize)
    .borderRadius(this.outerSize / 2)
    .clip(true)
  }
}
