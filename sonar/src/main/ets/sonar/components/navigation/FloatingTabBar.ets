import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { PlaybackController } from '../../playback/PlaybackController';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { MiniBarCoverDisc } from './MiniBarCoverDisc';
import {

  HdsBarWidthRangeOptions,

  HdsTabs,

  HdsTabsBackgroundStyle,

  HdsTabsController,

  HdsTabsFloatingStyle,

  HdsTabsMiniBar,

  SystemMaterialParams,

  hdsMaterial
} from '@kit.UIDesignKit';
import deviceInfo from '@ohos.deviceInfo';
interface RootTabItem {

  pageIndex: number;

  icon: Resource;

  a11yLabel: string;
}
const ROOT_TAB_ITEMS: RootTabItem[] = [

  { pageIndex: 0, icon: $r('app.media.tab_library'), a11yLabel: '媒体库' },

  { pageIndex: 1, icon: $r('app.media.tab_server'), a11yLabel: '服务器' },

  { pageIndex: 2, icon: $r('app.media.tab_profile'), a11yLabel: '我的' },
];
const HDS_SIDE_MARGIN_SMALL: number = 16;
const HDS_SIDE_MARGIN_MEDIUM: number = 24;
const HDS_SIDE_MARGIN_LARGE: number = 32;
const WIDTH_BREAKPOINT_MEDIUM: number = 600;
const WIDTH_BREAKPOINT_LARGE: number = 840;
@Component
export struct FloatingTabBar {

  @StorageLink('rootTabIndex') rootTabIndex: number = 0;

  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();

  @StorageProp('bottomRectHeight') bottomInset: number = 0;

  private hdsTabsController: HdsTabsController = new HdsTabsController();

  @State private containerWidth: number = 360;

  @State private customMaterialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.ADAPTIVE;

  @State private customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  aboutToAppear(): void {

    AppStorage.setOrCreate<boolean>('rootTabActive', true);

    this.initMaterialEffect();

  }

  aboutToDisappear(): void {

    AppStorage.setOrCreate<boolean>('rootTabActive', false);

  }

  private supportsHdsTabs(): boolean {

    return deviceInfo.distributionOSApiVersion >= 60100;

  }

  private initMaterialEffect(): void {

    const supportedTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();

    if (supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {

      this.customMaterialType = hdsMaterial.MaterialType.NONE;

      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

      return;

    }

    this.customMaterialType = hdsMaterial.MaterialType.ADAPTIVE;

    this.customMaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  }

  private buildTabBarMaterialEffect(): SystemMaterialParams {

    return {

      materialType: this.customMaterialType,

      materialLevel: this.customMaterialLevel

    };

  }

  private resolveSideMargin(): number {

    if (this.containerWidth >= WIDTH_BREAKPOINT_LARGE) {

      return HDS_SIDE_MARGIN_LARGE;

    }

    if (this.containerWidth >= WIDTH_BREAKPOINT_MEDIUM) {

      return HDS_SIDE_MARGIN_MEDIUM;

    }

    return HDS_SIDE_MARGIN_SMALL;

  }

  private resolveDockExpandedWidthVp(): number {

    if (this.containerWidth >= WIDTH_BREAKPOINT_LARGE) {

      return UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE;

    }

    if (this.containerWidth >= WIDTH_BREAKPOINT_MEDIUM) {

      return UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM;

    }

    return UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL;

  }

  private resolveFloatingBarWidth(): HdsBarWidthRangeOptions {

    const expandedWidth: HdsBarWidthRangeOptions = {

      smallWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL,

      mediumWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM,

      largeWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE

    };

    return expandedWidth;

  }

  private buildBarFloatingStyle(): HdsTabsFloatingStyle {

    const barWidth: HdsBarWidthRangeOptions = this.resolveFloatingBarWidth();

    const gradientMask: HdsTabsBackgroundStyle = {

      maskColor: UiTokens.COLOR_OVERLAY_SCRIM,

      maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + 16

    };

    const miniBar: HdsTabsMiniBar = {

      miniBarBuilder: () => {

        this.miniBarBuilder();

      }

    };

    const style: HdsTabsFloatingStyle = {

      barWidth: barWidth,

      barBottomMargin: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset,

      barSideMargin: this.resolveSideMargin(),

      gradientMask: gradientMask,

      systemMaterialEffect: this.buildTabBarMaterialEffect(),

      miniBar: miniBar

    };

    return style;

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

  private togglePlayback(): void {

    void PlaybackController.toggle();

  }

  private nextTrack(): void {

    void PlaybackController.playNext(true);

  }

  private toggleMode(): void {

    PlaybackController.togglePlaybackMode();

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

      this.togglePlayback();

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

      this.toggleMode();

    })

  }

  /**
   * 与官方 miniBar 示例一致：单一 Row，折叠/展开由 HDS 改变槽宽；窄槽靠 clip 只露出左侧圆盘。
   * @see https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-tabs-bar-floating
   * @see https://developer.huawei.com/consumer/cn/blog/topic/03215488109625113
   */
  @Builder
  private miniBarBuilder() {
    Row({ space: UiTokens.MINI_PLAYER_CAPSULE_CONTENT_GAP }) {
      MiniBarCoverDisc({
        outerSize: this.coverOuterSize(),
        coverInset: this.coverInset()
      })
        .flexShrink(0)

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
      .flexShrink(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Row({ space: UiTokens.MINI_PLAYER_ACTION_ICON_GAP }) {
        this.playPauseButton(22)
        this.actionIcon($r('app.media.cb_next'), 22, () => {
          this.nextTrack();
        })
        this.playbackModeButton(20)
      }
      .flexShrink(0)
      .visibility(this.hasActiveTrack() ? Visibility.Visible : Visibility.None)
    }
    .width('100%')
    .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .clip(true)
  }

  /** HDS 悬浮页签须用 BottomTabBarStyle；CustomBuilder 会不可见但仍可点击 */
  private buildHdsTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    return new BottomTabBarStyle(item.icon, item.a11yLabel)
      .labelStyle({
        selectedColor: UiTokens.COLOR_PRIMARY,
        unselectedColor: $r('sys.color.ohos_id_color_primary_contrary')
      })
      .iconStyle({
        selectedColor: UiTokens.COLOR_PRIMARY,
        unselectedColor: $r('sys.color.ohos_id_color_primary_contrary')
      });
  }

  @Builder

  private buildHdsTabs() {

    HdsTabs({ controller: this.hdsTabsController, index: this.rootTabIndex }) {

      TabContent() {

        LibraryPage()

      }

      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[0]))

      TabContent() {

        ServerPage()

      }

      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[1]))

      TabContent() {

        ProfilePage()

      }

      .tabBar(this.buildHdsTabBarStyle(ROOT_TAB_ITEMS[2]))

    }

    .barOverlap(true)

    .barPosition(BarPosition.End)

    .barMode(BarMode.Fixed)

    .vertical(false)

    .scrollable(false)

    .animationDuration(0)

    .barHeight(UiTokens.FLOATING_TAB_BAR_HEIGHT)

    .barFloatingStyle(this.buildBarFloatingStyle())

    .onChange((index: number) => {

      this.rootTabIndex = index;

    })

    .width('100%')

    .height('100%')

  }

  @Builder

  private buildFallbackTabs() {

    Tabs({ barPosition: BarPosition.End, index: this.rootTabIndex }) {

      TabContent() {

        LibraryPage()

      }

      .tabBar($r('app.media.tab_library'))

      TabContent() {

        ServerPage()

      }

      .tabBar($r('app.media.tab_server'))

      TabContent() {

        ProfilePage()

      }

      .tabBar($r('app.media.tab_profile'))

    }

    .barOverlap(true)

    .scrollable(false)

    .animationDuration(0)

    .onChange((index: number) => {

      this.rootTabIndex = index;

    })

    .width('100%')

    .height('100%')

  }

  build() {

    Stack() {

      if (this.supportsHdsTabs()) {

        this.buildHdsTabs()

      } else {

        this.buildFallbackTabs()

      }

    }

    .width('100%')

    .height('100%')

    .onAreaChange((_oldValue, newValue) => {

      if (typeof newValue.width === 'number') {

        this.containerWidth = newValue.width;

      } else if (typeof newValue.width === 'string') {

        const parsed: number = Number.parseFloat(newValue.width);

        if (Number.isFinite(parsed)) {

          this.containerWidth = parsed;

        }

      }

    })

  }
}

