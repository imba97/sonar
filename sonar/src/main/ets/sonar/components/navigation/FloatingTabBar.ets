import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { ImmersiveMaterialHelper } from '../../ui/material/ImmersiveMaterialHelper';
import { BarToneStore } from '../../ui/color/BarToneStore';
import { BarToneSampler } from '../../ui/color/BarToneSampler';
import { BarToneColorAnimator } from '../../ui/color/BarToneColorAnimator';
import { MiniBarRow } from './MiniBarRow';
import {
  HdsBarWidthRangeOptions,
  HdsTabs,
  HdsTabsBackgroundStyle,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HdsTabsMiniBar
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
const BAR_TONE_COLOR_ANIM_MS: number = 280;

@Component
export struct FloatingTabBar {
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('barToneUseLightForeground') @Watch('onBarToneChange') barToneUseLightForeground: boolean = false;
  @StorageLink('currentColorMode') @Watch('onColorModeChange') currentColorMode: number = 0;

  @State private displayTabInactive: string = '#282A32';
  @State private miniTargetInactive: string = '#282A32';
  @State private miniTargetPrimary: string = '#1B1D23';
  @State private miniTargetSecondary: string = '#3C3F4A';
  @State private barToneAppliedLight: boolean = false;
  @State private barToneColorsReady: boolean = false;

  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private tabColorAnimator: BarToneColorAnimator = new BarToneColorAnimator();
  @State private containerWidth: number = 360;

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', true);
    BarToneStore.ensureInitialized();
    BarToneStore.resetBaseline(this.rootTabIndex, BarToneStore.isDarkMode());
    this.applyBarToneColors(false);
    BarToneSampler.start(this.getUIContext());
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', false);
    BarToneSampler.stop();
    this.tabColorAnimator.stop();
  }

  private supportsHdsTabs(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
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

  private resolveFloatingBarWidth(): HdsBarWidthRangeOptions {
    return {
      smallWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL,
      mediumWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM,
      largeWidth: UiTokens.FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE
    };
  }

  private buildBarFloatingStyle(): HdsTabsFloatingStyle {
    const miniBar: HdsTabsMiniBar = {
      miniBarBuilder: () => {
        this.miniBarBuilder();
      }
    };
    return {
      barWidth: this.resolveFloatingBarWidth(),
      barBottomMargin: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset,
      barSideMargin: this.resolveSideMargin(),
      gradientMask: {
        maskColor: UiTokens.COLOR_OVERLAY_SCRIM,
        maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + 16
      },
      systemMaterialEffect: ImmersiveMaterialHelper.buildNavigationEffect(),
      miniBar: miniBar
    };
  }

  private applyBarToneColors(animated: boolean): void {
    const useLight: boolean = this.barToneUseLightForeground;
    if (this.barToneColorsReady && useLight === this.barToneAppliedLight) {
      return;
    }
    const next = BarToneStore.resolveForegroundColors(useLight, BarToneStore.isDarkMode());
    this.barToneAppliedLight = useLight;
    this.miniTargetInactive = next.tabInactive;
    this.miniTargetPrimary = next.barPrimary;
    this.miniTargetSecondary = next.barSecondary;

    const shouldAnimate: boolean = animated && this.barToneColorsReady;
    if (shouldAnimate) {
      this.tabColorAnimator.animateHex(
        this.displayTabInactive,
        next.tabInactive,
        BAR_TONE_COLOR_ANIM_MS,
        (value: string) => {
          this.displayTabInactive = value;
        }
      );
    } else {
      this.tabColorAnimator.stop();
      this.displayTabInactive = next.tabInactive;
    }
    this.barToneColorsReady = true;
  }

  private onBarToneChange(): void {
    this.applyBarToneColors(true);
  }

  private syncBarToneBaseline(): void {
    BarToneStore.resetBaseline(this.rootTabIndex, BarToneStore.isDarkMode());
  }

  private onColorModeChange(): void {
    this.syncBarToneBaseline();
  }

  @Builder
  private miniBarBuilder() {
    MiniBarRow({
      targetInactive: this.miniTargetInactive,
      targetPrimary: this.miniTargetPrimary,
      targetSecondary: this.miniTargetSecondary
    })
  }

  private buildHdsTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    return new BottomTabBarStyle(item.icon, item.a11yLabel)
      .labelStyle({
        selectedColor: UiTokens.COLOR_PRIMARY,
        unselectedColor: this.displayTabInactive
      })
      .iconStyle({
        selectedColor: UiTokens.COLOR_PRIMARY,
        unselectedColor: this.displayTabInactive
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
      this.syncBarToneBaseline();
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
      this.syncBarToneBaseline();
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
