import { SonicApiEntryModule } from '../view/SonicApiEntryModule';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ServerPage {
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('rootTabIndex') rootTabIndex: number = 0;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('networkType') networkType: string = 'none';

  private describeNetworkType(): string {
    switch (this.networkType) {
      case 'wifi':
        return 'WIFI';
      case 'cellular':
        return '蜂窝移动网络';
      case 'none':
        return '无网络';
      default:
        return '其他网络';
    }
  }

  build() {
    PageScaffold({
      pageBackground: UiTokens.COLOR_PAGE_BG,
      topPadding: 10,
      barToneTabIndex: 1,
      bottomPadding: this.rootTabActive ? UiTokens.MINI_PLAYER_WITH_TAB_BOTTOM_PADDING :
        UiTokens.BOTTOM_PADDING_WITH_TAB_BAR
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

        Column() {
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
              Text(`当前网络：${this.describeNetworkType()}`)
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }
}
