import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
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

@Component
export struct FloatingTabBar {
  @StorageLink('rootTabIndex') currentIndex: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  private hdsTabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', true);
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', false);
  }

  private supportsHdsTabs(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
  }

  private onTabIndexChange(index: number): void {
    AppStorage.setOrCreate<number>('rootTabIndex', index);
  }

  @Builder
  private buildIconTabBar(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon)
        .width(UiTokens.TAB_BAR_ICON_SIZE)
        .height(UiTokens.TAB_BAR_ICON_SIZE)
        .fillColor(this.currentIndex === index ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TAB_ICON_INACTIVE)
        .opacity(this.currentIndex === index ? 1 : 0.85)
        .accessibilityText(label)
    }
    .width(UiTokens.TAB_BAR_ICON_SIZE)
    .height(UiTokens.TAB_BAR_ICON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private fallbackTabButton(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon)
        .width(UiTokens.TAB_BAR_ICON_SIZE)
        .height(UiTokens.TAB_BAR_ICON_SIZE)
        .fillColor(this.currentIndex === index ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TAB_ICON_INACTIVE)
        .opacity(this.currentIndex === index ? 1 : 0.85)
        .accessibilityText(label)
    }
    .width(UiTokens.TAB_BAR_ICON_SIZE)
    .height(UiTokens.TAB_BAR_ICON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabIndexChange(index);
    })
  }

  @Builder
  private buildFallbackGlassBar() {
    Column() {
      Row({ space: UiTokens.TAB_BAR_ICON_GAP }) {
        ForEach(ROOT_TAB_ITEMS, (item: RootTabItem) => {
          this.fallbackTabButton(item.pageIndex, item.icon, item.a11yLabel)
        }, (item: RootTabItem) => `${item.pageIndex}`)
      }
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .borderRadius(UiTokens.FLOATING_TAB_BAR_HEIGHT / 2)
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
      .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset })
  }

  @Builder
  private buildHdsTabs() {
    HdsTabs({ controller: this.hdsTabsController, index: this.currentIndex }) {
      TabContent() {
        LibraryPage()
      }
      .tabBar(this.buildIconTabBar(0, ROOT_TAB_ITEMS[0].icon, ROOT_TAB_ITEMS[0].a11yLabel))

      TabContent() {
        ServerPage()
      }
      .tabBar(this.buildIconTabBar(1, ROOT_TAB_ITEMS[1].icon, ROOT_TAB_ITEMS[1].a11yLabel))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.buildIconTabBar(2, ROOT_TAB_ITEMS[2].icon, ROOT_TAB_ITEMS[2].a11yLabel))
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    .scrollable(false)
    .animationDuration(0)
    .barFloatingStyle({
      barWidth: {
        smallWidth: UiTokens.FLOATING_TAB_BAR_COMPACT_WIDTH,
        mediumWidth: UiTokens.FLOATING_TAB_BAR_COMPACT_WIDTH + 16,
        largeWidth: UiTokens.FLOATING_TAB_BAR_COMPACT_WIDTH + 32
      },
      barBottomMargin: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset,
      barSideMargin: 0,
      lightColor: UiTokens.COLOR_GLASS_BAR_BORDER,
      gradientMask: {
        maskColor: UiTokens.COLOR_OVERLAY_SCRIM,
        maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + 16
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .onChange((index: number) => {
      this.onTabIndexChange(index);
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildFallbackTabs() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          LibraryPage()
        }

        TabContent() {
          ServerPage()
        }

        TabContent() {
          ProfilePage()
        }
      }
      .barHeight(0)
      .barOverlap(true)
      .divider(null)
      .scrollable(false)
      .animationDuration(0)
      .onChange((index: number) => {
        this.onTabIndexChange(index);
      })
      .width('100%')
      .height('100%')

      this.buildFallbackGlassBar()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (this.supportsHdsTabs()) {
      this.buildHdsTabs()
    } else {
      this.buildFallbackTabs()
    }
  }
}
