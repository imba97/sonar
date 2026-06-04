import { SubsonicClient } from '../../api/SubsonicClient';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct MiniBarCoverDisc {
  @Prop outerSize: number = UiTokens.FLOATING_TAB_BAR_HEIGHT;
  @Prop coverInset: number = UiTokens.MINI_BAR_BALL_COVER_INSET;
  @Prop rotateDeg: number = 0;
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('nowPlayingCoverArt') nowPlayingCoverArt: string = '';

  private innerSize(): number {
    return Math.max(0, this.outerSize - this.coverInset * 2);
  }

  private hasActiveTrack(): boolean {
    return this.showMiniPlayer;
  }

  private idleIconSize(): number {
    return this.innerSize() > 0 ? Math.floor(this.innerSize() * 0.52) : 22;
  }

  @Builder
  private defaultMusicIcon() {
    Image($r('app.media.dock_music_note'))
      .width(this.idleIconSize())
      .height(this.idleIconSize())
      .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      .objectFit(ImageFit.Contain)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasActiveTrack() && this.nowPlayingCoverArt.length > 0) {
        Image(SubsonicClient.getInstance().getCoverArtUrl(this.nowPlayingCoverArt, 160))
          .width(this.innerSize())
          .height(this.innerSize())
          .borderRadius(this.innerSize() / 2)
          .objectFit(ImageFit.Cover)
          .alt($r('app.media.dock_music_note'))
          .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
          .clip(true)
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            angle: this.rotateDeg,
            centerX: '50%',
            centerY: '50%'
          })
      } else if (this.hasActiveTrack()) {
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
