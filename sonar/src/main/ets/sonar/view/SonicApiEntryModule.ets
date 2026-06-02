import { TagButton } from '../components/buttons/TagButton';
import { CardContainer } from '../components/layout/CardContainer';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct SonicApiEntryModule {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInEndpoint') loggedInEndpoint: string = 'remote';

  private stripScheme(url: string): string {
    if (!url) {
      return '';
    }
    return url.replace(/^https?:\/\//, '');
  }

  build() {
    Column() {
      CardContainer() {
        Row() {
          Column() {
            Text(this.isLoggedIn ? '🛰 Sonar Cloud 已连接' : '☁ Sonar Cloud')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            if (this.isLoggedIn) {
              Text(`${this.loggedInUser} · ${this.stripScheme(this.loggedInServer)}`)
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            } else {
              Text('登录到你的自部署音乐服务器')
                .fontSize(12)
                .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          TagButton({
            text: this.isLoggedIn ? '进入媒体库' : '连接服务器',
            fontColor: '#FFFFFF',
            bgColor: this.isLoggedIn ? UiTokens.COLOR_PRIMARY : '#34C759',
            onPressed: () => {
              if (this.isLoggedIn) {
                AppStorage.setOrCreate<number>('rootTabIndex', 0);
              } else {
                this.appPathStack.pushPathByName('LoginPage', null);
              }
            }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      if (this.isLoggedIn) {
        Row() {
          Text(`已启用 Subsonic API · 当前环境: ${this.loggedInEndpoint === 'local' ? '本地' : '远程'}`)
            .fontSize(11)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .padding({ left: 4, top: 6 })
      }
    }
    .width('92%')
    .margin({ top: 12, bottom: 6 })
  }
}
