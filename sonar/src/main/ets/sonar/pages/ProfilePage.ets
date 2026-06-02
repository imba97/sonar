import { AuthSession } from '../auth/AuthSession';
import { DangerButton } from '../components/buttons/DangerButton';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';

const LOGOUT_DESTINATION_TAB_INDEX: number = 1;

@Component
export struct ProfilePage {
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInServer') loggedInServer: string = '';

  private async handleLogout(): Promise<void> {
    await AuthSession.logout();
    AppStorage.setOrCreate<number>('rootTabIndex', LOGOUT_DESTINATION_TAB_INDEX);
  }

  build() {
    PageScaffold({
      pageBackground: UiTokens.COLOR_PAGE_BG,
      topPadding: 10,
      bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_WITH_TAB_BOTTOM_PADDING :
        UiTokens.BOTTOM_PADDING_WITH_TAB_BAR
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
                  this.handleLogout().catch((err: Error) => {
                    console.error(`logout failed: ${err.message}`);
                  });
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
