import { LibraryPage } from '../../pages/LibraryPage';
import { ServerPage } from '../../pages/ServerPage';
import { ProfilePage } from '../../pages/ProfilePage';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct FloatingTabBar {
  @StorageLink('rootTabIndex') currentIndex: number = 0;

  aboutToAppear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', true);
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('rootTabActive', false);
  }

  @Builder
  private tabItem(index: number, icon: Resource, title: string) {
    Column() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor(this.currentIndex === index ? UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_SECONDARY)
        .opacity(this.currentIndex === index ? 1 : 0.68)
        .accessibilityText(title)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        LibraryPage()
      }
      .tabBar(this.tabItem(0, $r('app.media.tab_library'), '媒体库'))

      TabContent() {
        ServerPage()
      }
      .tabBar(this.tabItem(1, $r('app.media.tab_server'), '服务器'))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabItem(2, $r('app.media.tab_profile'), '我的'))
    }
    .barHeight(UiTokens.FLOATING_TAB_BAR_HEIGHT)
    .barMode(BarMode.Fixed)
    .barOverlap(true)
    .barBackgroundColor('#D9FFFFFF')
    .barBackgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .borderRadius(22)
    .margin({ left: 12, right: 12, bottom: UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN })
    .onChange((index: number) => {
      AppStorage.setOrCreate<number>('rootTabIndex', index);
    })
    .scrollable(false)
  }
}
