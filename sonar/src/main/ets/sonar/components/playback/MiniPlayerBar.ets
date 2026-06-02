import { PlaybackSession } from '../../playback/PlaybackSession';
import { SubsonicClient } from '../../api/SubsonicClient';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct MiniPlayerBar {
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('nowPlayingTitle') nowPlayingTitle: string = '';
  @StorageLink('nowPlayingArtist') nowPlayingArtist: string = '';
  @StorageLink('nowPlayingCoverArt') nowPlayingCoverArt: string = '';
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('playbackMode') playbackMode: string = 'listLoop';
  @StorageLink('playbackProgressMs') playbackProgressMs: number = 0;
  @StorageLink('playbackDurationMs') playbackDurationMs: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State private draggingValueMs: number = 0;
  @State private dragging: boolean = false;
  @State private expanded: boolean = false;

  private effectiveDurationMs(): number {
    if (this.playbackDurationMs > 0) {
      return this.playbackDurationMs;
    }
    if (this.dragging && this.draggingValueMs > 0) {
      return this.draggingValueMs;
    }
    return 0;
  }

  private clampProgress(value: number): number {
    const durationMs: number = this.effectiveDurationMs();
    if (durationMs <= 0) {
      return 0;
    }
    if (value < 0) {
      return 0;
    }
    if (value > durationMs) {
      return durationMs;
    }
    return value;
  }

  private formatTime(ms: number): string {
    const totalSeconds: number = Math.floor(ms / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    const secondText: string = seconds < 10 ? `0${seconds}` : String(seconds);
    return `${minutes}:${secondText}`;
  }

  private collapsedBottomMargin(): number {
    return (this.rootTabActive ? UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN :
      UiTokens.MINI_PLAYER_BASE_MARGIN_BOTTOM) + this.bottomInset;
  }

  private expandedBottomMargin(): number {
    return (this.rootTabActive ? UiTokens.MINI_PLAYER_TAB_OFFSET :
      UiTokens.MINI_PLAYER_BASE_MARGIN_BOTTOM) + this.bottomInset;
  }

  @Builder
  private iconButton(icon: Resource, onTap: () => void) {
    Button() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
    }
    .width(40)
    .height(40)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  private playPauseButton() {
    Button() {
      Image(this.isPlaying ? $r('app.media.cb_pause') : $r('app.media.cb_play'))
        .width(30)
        .height(30)
        .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
    }
    .width(44)
    .height(44)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.isPlaying = !this.isPlaying;
      void PlaybackSession.togglePlayPause();
    })
  }

  @Builder
  private modeButton() {
    Button() {
      if (this.playbackMode === 'singleLoop') {
        Image($r('app.media.cb_mode_loop'))
          .width(24)
          .height(24)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      } else if (this.playbackMode === 'random') {
        Image($r('app.media.cb_mode_shuffle'))
          .width(24)
          .height(24)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      } else {
        Image($r('app.media.cb_mode_list'))
          .width(24)
          .height(24)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
    }
    .width(40)
    .height(40)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      const nextMode: string = PlaybackSession.togglePlaybackMode();
      this.playbackMode = nextMode;
    })
  }

  @Builder
  private collapsedButton() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.nowPlayingCoverArt.length > 0) {
          Image(SubsonicClient.getInstance().getCoverArtUrl(this.nowPlayingCoverArt, 160))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .alt($r('app.media.cb_play'))
            .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
        } else {
          Image($r('app.media.cb_play'))
            .width(24)
            .height(24)
            .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
        }
      }
      .width(UiTokens.FLOATING_TAB_BAR_HEIGHT)
      .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
      .borderRadius(UiTokens.FLOATING_TAB_BAR_HEIGHT / 2)
      .clip(true)
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .onClick(() => {
        this.expanded = true;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.End)
    .padding({ right: 16 })
    .margin({ bottom: this.collapsedBottomMargin() })
    .hitTestBehavior(HitTestMode.None)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.showMiniPlayer && this.expanded) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(UiTokens.COLOR_OVERLAY_SCRIM)
          .onClick(() => {
            this.expanded = false;
          })
      }

      if (this.showMiniPlayer) {
        if (this.expanded) {
          this.expandedBar()
        } else {
          this.collapsedButton()
        }
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(this.expanded ? HitTestMode.Default : HitTestMode.None)
  }

  @Builder
  private expandedBar() {
    Column() {
      Column() {
        Row() {
          Column() {
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
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Row({ space: 8 }) {
            this.iconButton($r('app.media.cb_prev'), () => {
                void PlaybackSession.playPrevious();
              })
            this.playPauseButton()
            this.iconButton($r('app.media.cb_next'), () => {
                void PlaybackSession.playNext(true);
              })
            this.modeButton()
          }
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 6 })

        Row() {
          Text(this.formatTime(this.clampProgress(this.dragging ? this.draggingValueMs : this.playbackProgressMs)))
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .width(40)
          Slider({
            min: 0,
            max: this.effectiveDurationMs() > 0 ? this.effectiveDurationMs() : 1,
            value: this.effectiveDurationMs() > 0 ?
              this.clampProgress(this.dragging ? this.draggingValueMs : this.playbackProgressMs) : 0
          })
            .layoutWeight(1)
            .enabled(this.effectiveDurationMs() > 0)
            .blockColor(UiTokens.COLOR_PRIMARY)
            .trackColor(UiTokens.COLOR_PRIMARY_SOFT_BG)
            .selectedColor(UiTokens.COLOR_PRIMARY)
            .onChange((value: number, mode: SliderChangeMode) => {
              const nextValue: number = this.clampProgress(Math.floor(value));
              if (this.effectiveDurationMs() <= 0) {
                return;
              }
              if (mode === SliderChangeMode.Begin) {
                this.dragging = true;
                this.draggingValueMs = nextValue;
                return;
              }
              if (mode === SliderChangeMode.Moving) {
                this.draggingValueMs = nextValue;
                return;
              }
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.dragging = false;
                this.draggingValueMs = nextValue;
                void PlaybackSession.seekTo(nextValue);
              }
            })
          Text(this.formatTime(this.effectiveDurationMs()))
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12, bottom: 10 })
      }
      .width('100%')
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      .borderRadius(18)
      .margin({ left: 16, right: 16, bottom: this.expandedBottomMargin() })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
