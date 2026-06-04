import { MiniBarCoverDisc } from '../navigation/MiniBarCoverDisc';
import { PlaybackController } from '../../playback/PlaybackController';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct MiniPlayerBar {
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;

  private collapsedBottomMargin(): number {
    return (this.rootTabActive ? UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN :
      UiTokens.MINI_PLAYER_BASE_MARGIN_BOTTOM) + this.bottomInset;
  }

  private expandedBottomMargin(): number {
    return (this.rootTabActive ? UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN :
      UiTokens.MINI_PLAYER_BASE_MARGIN_BOTTOM) + this.bottomInset;
  }

  private toggleDockSwapped(nextValue: boolean): void {
    if (this.playback.bottomDockSwapped === nextValue) {
      return;
    }
    animateTo({
      duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION,
      curve: Curve.EaseInOut
    }, () => {
      PlaybackController.setBottomDockSwapped(nextValue);
    });
  }

  private hasActiveTrack(): boolean {
    return this.playback.showMiniPlayer;
  }

  @Builder
  private actionIcon(icon: Resource, iconSize: number, onTap: () => void) {
    Column() {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
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
  private playPauseButton(iconSize: number) {
    Column() {
      if (this.playback.isPlaying()) {
        Image($r('app.media.cb_pause'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      } else {
        Image($r('app.media.cb_play'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      void PlaybackController.toggle();
    })
  }

  @Builder
  private playbackModeButton(iconSize: number) {
    Column() {
      if (this.playback.mode === 'singleLoop') {
        Image($r('app.media.cb_mode_loop'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      } else if (this.playback.mode === 'random') {
        Image($r('app.media.cb_mode_shuffle'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      } else {
        Image($r('app.media.cb_mode_list'))
          .width(iconSize)
          .height(iconSize)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
    }
    .width(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .height(UiTokens.MINI_PLAYER_ACTION_TOUCH_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      PlaybackController.togglePlaybackMode();
    })
  }

  @Builder
  private coverDisc(size: number, clickable: boolean = false) {
    if (clickable) {
      Stack({ alignContent: Alignment.Center }) {
        MiniBarCoverDisc({
          outerSize: size,
          coverInset: 0
        })
      }
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .clip(true)
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .onClick(() => {
        this.toggleDockSwapped(true);
      })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        MiniBarCoverDisc({
          outerSize: size,
          coverInset: 0
        })
      }
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .clip(true)
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
    }
  }

  @Builder
  private collapsedButton() {
    Column() {
      this.coverDisc(UiTokens.DOCK_BALL_SIZE, true)
    }
    .width(UiTokens.DOCK_BALL_SIZE)
    .height(UiTokens.DOCK_BALL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: UiTokens.DOCK_SIDE_MARGIN })
    .margin({ bottom: this.collapsedBottomMargin() })
    .hitTestBehavior(HitTestMode.Transparent)
    .animation({ duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION, curve: Curve.EaseInOut })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.rootTabActive) {
        if (this.playback.bottomDockSwapped) {
          this.expandedBar()
        } else {
          this.collapsedButton()
        }
      }
    }
    .width('100%')
    .hitTestBehavior(HitTestMode.Transparent)
    .animation({ duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION, curve: Curve.EaseInOut })
  }

  @Builder
  private expandedBar() {
    Column() {
      Row({ space: UiTokens.MINI_PLAYER_CAPSULE_CONTENT_GAP }) {
        this.coverDisc(UiTokens.MINI_PLAYER_CAPSULE_COVER_SIZE)

        Column({ space: 2 }) {
          Text(this.hasActiveTrack() ?
            (this.playback.track !== null && this.playback.track.title.length > 0 ?
              this.playback.track.title : '未知曲目') : '当前未播放音乐')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.hasActiveTrack()) {
            Text(this.playback.track !== null && this.playback.track.artist.length > 0 ?
              this.playback.track.artist : '未知歌手')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Row({ space: UiTokens.MINI_PLAYER_ACTION_ICON_GAP }) {
          this.playPauseButton(24)
          this.actionIcon($r('app.media.cb_next'), 24, () => {
            void PlaybackController.playNext(true);
          })
          this.playbackModeButton(22)
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(UiTokens.MINI_PLAYER_CAPSULE_HEIGHT)
      .constraintSize({ maxWidth: UiTokens.MINI_PLAYER_CAPSULE_MAX_WIDTH })
      .padding({
        left: UiTokens.MINI_PLAYER_CAPSULE_HORIZONTAL_PADDING,
        right: UiTokens.MINI_PLAYER_CAPSULE_HORIZONTAL_PADDING
      })
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .borderRadius(UiTokens.MINI_PLAYER_CAPSULE_HEIGHT / 2)
      .margin({
        left: UiTokens.DOCK_SIDE_MARGIN,
        right: UiTokens.DOCK_SIDE_MARGIN + UiTokens.DOCK_BALL_SIZE + UiTokens.DOCK_COMPONENT_GAP,
        bottom: this.expandedBottomMargin()
      })
      .opacity(this.playback.bottomDockSwapped ? 1 : 0)
      .animation({
        duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION,
        curve: Curve.EaseInOut
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: UiTokens.DOCK_SIDE_MARGIN })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
