import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { ImmersiveMaterialHelper } from '../../ui/material/ImmersiveMaterialHelper';
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

@Component
export struct FloatingTabBar {
  @StorageLink('rootTabIndex') currentIndex: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  @State private immersiveMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', true);
    this.resolveImmersiveMaterialLevel();
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

  private resolveImmersiveMaterialLevel(): void {
    // style.mdc: 关键容器优先 ADAPTIVE，设备不支持 IMMERSIVE 时降级到 SMOOTH。
    this.immersiveMaterialLevel = ImmersiveMaterialHelper.resolveMaterialLevel();
  }

  private buildTabBarMaterialEffect(): SystemMaterialParams {
    return ImmersiveMaterialHelper.buildAdaptiveEffect(this.immersiveMaterialLevel);
  }

  private activeTabColor(): ResourceColor {
    // 选中态固定主色（品牌蓝）。
    return UiTokens.COLOR_PRIMARY;
  }

  private inactiveTabColor(): ResourceColor {
    // 非激活态使用黑/白动态主文本色（浅色主题黑、深色主题白）。
    return UiTokens.COLOR_TEXT_PRIMARY;
  }

  private isTabSelected(index: number): boolean {
    return this.currentIndex === index;
  }

  private tabColorByIndex(index: number): ResourceColor {
    return this.isTabSelected(index) ? this.activeTabColor() : this.inactiveTabColor();
  }

  private buildHdsTabBarStyle(item: RootTabItem): BottomTabBarStyle {
    // 对 HDS 分支使用系统 BottomTabBarStyle：
    // 激活态固定品牌蓝；非激活态使用系统 contrary 颜色，让系统基于沉浸背景做黑/白对比。
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
  private buildIconTabBar(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.tabColorByIndex(index))
        .opacity(1)
        .accessibilityText(label)

      Text(label)
        .fontSize(10)
        .fontWeight(this.isTabSelected(index) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.tabColorByIndex(index))
        .margin({ top: 2 })
        .opacity(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private fallbackTabButton(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.tabColorByIndex(index))
        .opacity(1)
        .accessibilityText(label)

      Text(label)
        .fontSize(10)
        .fontWeight(this.isTabSelected(index) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.tabColorByIndex(index))
        .margin({ top: 2 })
        .opacity(1)
    }
    .width(58)
    .height(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabIndexChange(index);
    })
  }

  @Builder
  private buildFallbackGlassBar() {
    Column() {
      Row({ space: UiTokens.TAB_BAR_ICON_GAP + 10 }) {
        ForEach(ROOT_TAB_ITEMS, (item: RootTabItem) => {
          this.fallbackTabButton(item.pageIndex, item.icon, item.a11yLabel)
        }, (item: RootTabItem) => `${item.pageIndex}`)
      }
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
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
    .animationDuration(240)
    .barHeight(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .barFloatingStyle({
      barWidth: {
        smallWidth: FLOATING_TAB_BAR_TEXT_WIDTH_SMALL,
        mediumWidth: FLOATING_TAB_BAR_TEXT_WIDTH_MEDIUM,
        largeWidth: FLOATING_TAB_BAR_TEXT_WIDTH_LARGE
      },
      barBottomMargin: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset,
      barSideMargin: 0,
      thermoCtrl: true,
      lightColor: UiTokens.COLOR_GLASS_BAR_BORDER,
      gradientMask: {
        maskColor: UiTokens.COLOR_OVERLAY_SCRIM,
        maskHeight: UiTokens.FLOATING_TAB_BAR_HEIGHT + 16
      },
      systemMaterialEffect: this.buildTabBarMaterialEffect()
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
