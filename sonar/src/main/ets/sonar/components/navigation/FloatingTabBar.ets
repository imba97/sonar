import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { BarToneCoordinator } from '../../ui/color/BarToneCoordinator';
import { BarToneStore } from '../../ui/color/BarToneStore';
import { BarToneSampler } from '../../ui/color/BarToneSampler';
import { HdsTabsShell } from './HdsTabsShell';
import { TabScrollerBridge } from '../../ui/layout/TabScrollerBridge';
import deviceInfo from '@ohos.deviceInfo';

@Component
export struct FloatingTabBar {
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @State private containerWidth: number = 360;

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', true);
    BarToneStore.ensureInitialized();
    BarToneStore.resetBaseline(this.rootTabIndex, BarToneStore.isDarkMode());
    BarToneSampler.start(this.getUIContext());
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', false);
    BarToneSampler.stop();
  }

  private supportsHdsTabs(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
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
      this.tabScrollerBridge.setActiveTab(index);
      BarToneStore.resetBaseline(index, BarToneStore.isDarkMode());
    })
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.supportsHdsTabs()) {
        HdsTabsShell({ containerWidth: this.containerWidth })
      } else {
        this.buildFallbackTabs()
      }
      BarToneCoordinator()
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue, newValue) => {
      let widthVp: number = 0;
      if (typeof newValue.width === 'number') {
        widthVp = newValue.width;
      } else if (typeof newValue.width === 'string') {
        const parsed: number = Number.parseFloat(newValue.width);
        if (Number.isFinite(parsed)) {
          widthVp = parsed;
        }
      }
      if (widthVp > 0 && widthVp !== this.containerWidth) {
        this.containerWidth = widthVp;
      }
    })
  }
}
