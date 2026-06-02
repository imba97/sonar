import { SonicApiEntryModule } from '../view/SonicApiEntryModule';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ServerPage {
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';

  build() {
    PageScaffold({
      pageBackground: UiTokens.COLOR_PAGE_BG,
      topPadding: 10,
      bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_WITH_TAB_BOTTOM_PADDING :
        UiTokens.FLOATING_TAB_BAR_CONTENT_PADDING
    }) {
      Column({ space: 12 }) {
        Row() {
          Text('服务器')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 0 })

        SonicApiEntryModule()

        CardContainer() {
          Column({ space: 8 }) {
            Text('连接状态')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(this.isLoggedIn ? '已登录服务器' : '未登录')
              .fontSize(13)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            if (this.isLoggedIn) {
              Text(`${this.loggedInServer} · ${this.loggedInEndpoint === 'local' ? '本地' : '远程'}`)
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
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
