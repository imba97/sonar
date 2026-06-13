import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { PlaylistSheetOpener } from '../playlist/PlaylistSheetOpener';
import { BarToneColorAnimator } from '../../ui/color/BarToneColorAnimator';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { MiniBarCoverDisc } from './MiniBarCoverDisc';

const BAR_TONE_COLOR_ANIM_MS: number = 280;
const TONE_COLOR_ANIM_CURVE: Curve = Curve.EaseInOut;

/**
 * 官方 miniBar 模型：单一 Row + width('100%') + clip(true)。
 * 目标色经 AppStorage 注入；BarToneColorAnimator 280ms 插值 + .animation 平滑。
 */
@Component
export struct MiniBarRow {
  @Prop @Watch('onToneTargetChange') targetInactive: string = '#282A32';
  @Prop @Watch('onToneTargetChange') targetPrimary: string = '#1B1D23';
  @Prop @Watch('onToneTargetChange') targetSecondary: string = '#3C3F4A';
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();

  @State private displayInactive: string = '#282A32';
  @State private displayPrimary: string = '#1B1D23';
  @State private displaySecondary: string = '#3C3F4A';
  @State private toneAnimReady: boolean = false;

  private colorAnimator: BarToneColorAnimator = new BarToneColorAnimator();

  aboutToAppear(): void {
    this.applyDisplayColors(false);
  }

  aboutToDisappear(): void {
    this.colorAnimator.stop();
  }

  private onToneTargetChange(): void {
    this.applyDisplayColors(this.toneAnimReady);
  }

  private applyDisplayColors(animated: boolean): void {
    if (!animated) {
      this.colorAnimator.stop();
      this.displayInactive = this.targetInactive;
      this.displayPrimary = this.targetPrimary;
      this.displaySecondary = this.targetSecondary;
      this.toneAnimReady = true;
      return;
    }

    this.colorAnimator.animateTriple(
      this.displayInactive,
      this.targetInactive,
      this.displayPrimary,
      this.targetPrimary,
      this.displaySecondary,
      this.targetSecondary,
      BAR_TONE_COLOR_ANIM_MS,
      (inactive: string, primary: string, secondary: string) => {
        this.displayInactive = inactive;
        this.displayPrimary = primary;
        this.displaySecondary = secondary;
      }
    );
  }

  private hasActiveTrack(): boolean {
    return this.playback.showMiniPlayer;
  }

  private coverOuterSize(): number {
    return UiTokens.FLOATING_TAB_BAR_HEIGHT;
  }

  private coverInset(): number {
    return UiTokens.MINI_BAR_BALL_COVER_INSET;
  }

  @Builder
  private actionIcon(icon: Resource, iconSize: number, onTap: () => void) {
    Column() {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .fillColor(this.displayPrimary)
        .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  private queueButton(iconSize: number) {
    Column() {
      Image($r('app.media.cb_queue'))
        .width(iconSize)
        .height(iconSize)
        .fillColor(this.displayPrimary)
        .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityText('播放列表')
    .onClick(() => {
      PlaylistSheetOpener.requestOpen();
    })
  }

  @Builder
  private playPauseButton(iconSize: number) {
    Column() {
      if (this.playback.isPlaying()) {
        Image($r('app.media.cb_pause'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(this.displayPrimary)
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      } else {
        Image($r('app.media.cb_play'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(this.displayPrimary)
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      }
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      void PlaybackService.toggle();
    })
  }

  @Builder
  private playbackModeButton(iconSize: number) {
    Column() {
      if (this.playback.mode === 'singleLoop') {
        Image($r('app.media.cb_mode_loop'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(this.displayPrimary)
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      } else if (this.playback.mode === 'random') {
        Image($r('app.media.cb_mode_shuffle'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(this.displayPrimary)
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      } else {
        Image($r('app.media.cb_mode_list'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(this.displayPrimary)
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
      }
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      PlaybackService.togglePlaybackMode();
    })
  }

  build() {
    Row({ space: UiTokens.MINI_PLAYER_CAPSULE_CONTENT_GAP }) {
      MiniBarCoverDisc({
        outerSize: this.coverOuterSize(),
        coverInset: this.coverInset(),
        idleIconColor: this.displayInactive
      })
        .flexShrink(0)

      Column({ space: 2 }) {
        Text(this.hasActiveTrack() ?
          (this.playback.track !== null && this.playback.track.title.length > 0 ?
            this.playback.track.title : '未知曲目') : '当前未播放音乐')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasActiveTrack() ? this.displayPrimary : this.displayInactive)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
        if (this.hasActiveTrack()) {
          Text(this.playback.track !== null && this.playback.track.artist.length > 0 ?
            this.playback.track.artist : '未知歌手')
            .fontSize(12)
            .fontColor(this.displaySecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({ duration: BAR_TONE_COLOR_ANIM_MS, curve: TONE_COLOR_ANIM_CURVE })
        }
      }
      .layoutWeight(1)
      .flexShrink(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Row({ space: UiTokens.MINI_PLAYER_ACTION_ICON_GAP }) {
        if (this.hasActiveTrack()) {
          this.playPauseButton(22)
          this.actionIcon($r('app.media.cb_next'), 22, () => {
            void PlaybackService.playNext(true);
          })
          this.playbackModeButton(20)
        }
        this.queueButton(20)
      }
      .flexShrink(0)
      .padding({ right: UiTokens.MINI_BAR_HORIZONTAL_INSET })
    }
    .width('100%')
    .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .clip(true)
  }
}
