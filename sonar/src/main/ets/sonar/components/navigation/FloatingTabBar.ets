import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { PlaybackSession } from '../../playback/PlaybackSession';
import { SubsonicClient } from '../../api/SubsonicClient';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { HdsTabs, HdsTabsController, SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';
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

const FLOATING_TAB_BAR_TEXT_WIDTH_SMALL: number = 228;
const FLOATING_TAB_BAR_TEXT_WIDTH_MEDIUM: number = 248;
const FLOATING_TAB_BAR_TEXT_WIDTH_LARGE: number = 268;
const HDS_SIDE_MARGIN_SMALL: number = 16;
const HDS_SIDE_MARGIN_MEDIUM: number = 24;
const HDS_SIDE_MARGIN_LARGE: number = 32;
const WIDTH_BREAKPOINT_MEDIUM: number = 600;
const WIDTH_BREAKPOINT_LARGE: number = 840;

@Component
export struct FloatingTabBar {
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('nowPlayingTitle') nowPlayingTitle: string = '';
  @StorageLink('nowPlayingArtist') nowPlayingArtist: string = '';
  @StorageLink('nowPlayingCoverArt') nowPlayingCoverArt: string = '';
  @StorageLink('isPlaying') isPlaying: boolean = false;
  @StorageLink('playbackMode') playbackMode: string = 'listLoop';
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

  private modeIcon(): Resource {
    if (this.playbackMode === 'singleLoop') {
      return $r('app.media.cb_mode_loop');
    }
    if (this.playbackMode === 'random') {
      return $r('app.media.cb_mode_shuffle');
    }
    return $r('app.media.cb_mode_list');
  }

  private togglePlayback(): void {
    void PlaybackSession.togglePlayPause();
  }

  private nextTrack(): void {
    void PlaybackSession.playNext(true);
  }

  private toggleMode(): void {
    this.playbackMode = PlaybackSession.togglePlaybackMode();
  }

  @Builder
  private coverDisc(size: number) {
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
          .width(22)
          .height(22)
          .fillColor(UiTokens.COLOR_TEXT_PRIMARY)
      }
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .clip(true)
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
  private miniBarBuilder() {
    if (!this.showMiniPlayer) {
      Row()
        .width(0.1)
        .height(0.1)
    } else {
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
          this.actionIcon(this.isPlaying ? $r('app.media.cb_pause') : $r('app.media.cb_play'), 22, () => {
            this.togglePlayback();
          })
          this.actionIcon($r('app.media.cb_next'), 22, () => {
            this.nextTrack();
          })
          this.actionIcon(this.modeIcon(), 20, () => {
            this.toggleMode();
          })
        }
      }
      .width('100%')
      .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
      .constraintSize({ maxWidth: UiTokens.MINI_PLAYER_CAPSULE_MAX_WIDTH })
      .padding({
        left: UiTokens.MINI_PLAYER_CAPSULE_HORIZONTAL_PADDING,
        right: UiTokens.MINI_PLAYER_CAPSULE_HORIZONTAL_PADDING
      })
    }
  }

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
    .barHeight(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .barFloatingStyle({
      barWidth: {
        smallWidth: FLOATING_TAB_BAR_TEXT_WIDTH_SMALL,
        mediumWidth: FLOATING_TAB_BAR_TEXT_WIDTH_MEDIUM,
        largeWidth: FLOATING_TAB_BAR_TEXT_WIDTH_LARGE
      },
      barBottomMargin: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset,
      barSideMargin: this.resolveSideMargin(),
      gradientMask: {
        maskColor: UiTokens.COLOR_OVERLAY_SCRIM,
        maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + 16
      },
      systemMaterialEffect: this.buildTabBarMaterialEffect(),
      miniBar: {
        miniBarBuilder: () => this.miniBarBuilder()
      }
    })
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
