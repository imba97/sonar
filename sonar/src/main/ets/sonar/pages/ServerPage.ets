import { SonicApiEntryModule } from '../view/SonicApiEntryModule';
import { CardContainer } from '../components/layout/CardContainer';
import { SonarPageLayout } from '../components/layout/SonarPageLayout';
import {
  SonarPageLayoutOptions,
  SonarPageRole,
  SonarScrollMode
} from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct ServerPage {
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';
  @StorageLink('networkType') networkType: string = 'none';

  private layoutOptions(): SonarPageLayoutOptions {
    return {
      role: SonarPageRole.TAB_ROOT,
      barToneTabIndex: 1,
      scrollMode: SonarScrollMode.SCROLL
    };
  }

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

  @LocalBuilder
  buildConnectionStatusCard() {
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

  @LocalBuilder
  buildServerBody() {
    Column({ space: UiTokens.SECTION_GAP }) {
      Column() {
        SonicApiEntryModule()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      CardContainer() {
        this.buildConnectionStatusCard()
      }
    }
    .width('100%')
  }

  build() {
    SonarPageLayout({
      options: this.layoutOptions(),
      content: this.buildServerBody
    })
  }
}
