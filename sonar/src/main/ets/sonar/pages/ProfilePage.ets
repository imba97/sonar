import { AuthSession } from '../auth/AuthSession';
import { DangerButton } from '../components/buttons/DangerButton';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ProfilePage {
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInServer') loggedInServer: string = '';

  private async handleLogout(): Promise<void> {
    await AuthSession.logout();
    AppStorage.setOrCreate<number>('rootTabIndex', 1);
  }

  build() {
    PageScaffold({
      pageBackground: UiTokens.COLOR_PAGE_BG,
      topPadding: 10,
      bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_WITH_TAB_BOTTOM_PADDING :
        UiTokens.FLOATING_TAB_BAR_CONTENT_PADDING
    }) {
      Column({ space: 12 }) {
        Row() {
          Text('我的')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 0 })

        CardContainer() {
          Column({ space: 10 }) {
            Text(this.isLoggedIn ? (this.loggedInUser.length > 0 ? this.loggedInUser : '已登录用户') : '未登录')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.isLoggedIn ? this.loggedInServer : '请先在服务器页完成登录')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            if (this.isLoggedIn) {
              DangerButton({
                text: '退出登录',
                onPressed: () => {
                  void this.handleLogout();
                }
              })
              .margin({ top: 6 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .margin({ left: 16, right: 16 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }
}
