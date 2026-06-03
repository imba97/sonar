import { PlaybackSession } from '../../playback/PlaybackSession';
import { SubsonicClient } from '../../api/SubsonicClient';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct MiniPlayerBar {
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('bottomDockSwapped') bottomDockSwapped: boolean = false;
  @StorageLink('nowPlayingTitle') nowPlayingTitle: string = '';
  @StorageLink('nowPlayingArtist') nowPlayingArtist: string = '';
  @StorageLink('nowPlayingCoverArt') nowPlayingCoverArt: string = '';
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('playbackMode') playbackMode: string = 'listLoop';
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
    if (this.bottomDockSwapped === nextValue) {
      return;
    }
    animateTo({
      duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION,
      curve: Curve.EaseInOut
    }, () => {
      this.bottomDockSwapped = nextValue;
    });
  }

  private modeIcon(): Resource {
    if (this.playbackMode === 'singleLoop') {
      return $r('app.media.cb_mode_loop');
    }
    if (this.playbackMode === 'random') {
      return $r('app.media.cb_mode_shuffle');
    }
    return $r('app.media.cb_mode_list');
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
  private coverDisc(size: number, clickable: boolean = false) {
    if (clickable) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.nowPlayingCoverArt.length > 0) {
          Image(SubsonicClient.getInstance().getCoverArtUrl(this.nowPlayingCoverArt, 160))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.cb_play'))
            .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
            .rotate({ x: 0, y: 0, z: 1, angle: this.isPlaying ? 360 : 0 })
            .animation({
              duration: UiTokens.DOCK_COVER_ROTATION_DURATION,
              curve: Curve.Linear,
              iterations: this.isPlaying ? -1 : 1,
              playMode: PlayMode.Normal
            })
        } else {
          Image($r('app.media.cb_play'))
            .width(24)
            .height(24)
            .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
        }
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
        if (this.nowPlayingCoverArt.length > 0) {
          Image(SubsonicClient.getInstance().getCoverArtUrl(this.nowPlayingCoverArt, 160))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.cb_play'))
            .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
            .rotate({ x: 0, y: 0, z: 1, angle: this.isPlaying ? 360 : 0 })
            .animation({
              duration: UiTokens.DOCK_COVER_ROTATION_DURATION,
              curve: Curve.Linear,
              iterations: this.isPlaying ? -1 : 1,
              playMode: PlayMode.Normal
            })
        } else {
          Image($r('app.media.cb_play'))
            .width(24)
            .height(24)
            .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
        }
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: UiTokens.DOCK_SIDE_MARGIN })
    .margin({ bottom: this.collapsedBottomMargin() })
    .hitTestBehavior(HitTestMode.Transparent)
    .animation({ duration: UiTokens.DOCK_SWITCH_ANIMATION_DURATION, curve: Curve.EaseInOut })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.showMiniPlayer) {
        if (this.bottomDockSwapped) {
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
          Text(this.nowPlayingTitle.length > 0 ? this.nowPlayingTitle : '未在播放')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.nowPlayingArtist.length > 0 ? this.nowPlayingArtist : '未知歌手')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Row({ space: UiTokens.MINI_PLAYER_ACTION_ICON_GAP }) {
          this.actionIcon(this.isPlaying ? $r('app.media.cb_pause') : $r('app.media.cb_play'), 24, () => {
            this.isPlaying = !this.isPlaying;
            void PlaybackSession.togglePlayPause();
          })
          this.actionIcon($r('app.media.cb_next'), 24, () => {
            void PlaybackSession.playNext(true);
          })
          this.actionIcon(this.modeIcon(), 22, () => {
            const nextMode: string = PlaybackSession.togglePlaybackMode();
            this.playbackMode = nextMode;
          })
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
      .opacity(this.bottomDockSwapped ? 1 : 0)
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
