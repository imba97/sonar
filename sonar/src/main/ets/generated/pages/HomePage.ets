import { SonicApiEntryModule } from '../../sonar/view/SonicApiEntryModule';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrimaryButton } from '../../sonar/components/buttons/PrimaryButton';
import { CardContainer } from '../../sonar/components/layout/CardContainer';
import { PageScaffold } from '../../sonar/components/layout/PageScaffold';
import { UiTokens } from '../../sonar/ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'Sonar.HomePage';

@Component
export struct HomePage {
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @Consume('appPathStack') appPathStack: NavPathStack;
  build() {
    if (!this.isLoggedIn) {
      // 未登录状态：整个页面只展示引导图与"连接服务器"按钮
      PageScaffold({
        pageBackground: $r('app.color.page_bg_color'),
        topPadding: 16,
        bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_BOTTOM_PADDING : 20
      }) {
        Column() {
          Column() {
            Text('🎧')
              .fontSize(120)
              .fontColor('rgba(10,132,255,0.7)')
            Text('Sonar')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
              .margin({ top: 24 })
            Text('让自部署音乐，回到你的口袋')
              .fontSize(13)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
              .margin({ top: 8 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            PrimaryButton({
              text: '连接服务器',
              onPressed: () => {
                hilog.info(DOMAIN, TAG, 'connect button clicked, pushPathByName(LoginPage)');
                try {
                  this.appPathStack.pushPathByName('LoginPage', null);
                  hilog.info(DOMAIN, TAG, 'pushPathByName returned ok, stack size=%{public}d', this.appPathStack.size());
                } catch (err) {
                  hilog.error(DOMAIN, TAG, 'pushPathByName threw: %{public}s', (err as Error).message);
                }
              }
            })
          }
            .width('80%')
            .margin({ bottom: 48, top: 16 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    } else {
      // 已登录状态：仅展示真实数据入口，避免模板静态数据干扰
      PageScaffold({
        pageBackground: $r('app.color.page_bg_color'),
        topPadding: 16,
        bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_BOTTOM_PADDING : 20
      }) {
        Column() {
          SonicApiEntryModule()
          Column() {
            CardContainer() {
              Column({ space: 10 }) {
                Text('已连接 SonicAPI / Navidrome')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                Text('点击上方“进入媒体库”即可查看服务器中的真实专辑数据')
                  .fontSize(13)
                  .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                PrimaryButton({
                  text: '打开媒体库',
                  onPressed: () => {
                    this.appPathStack.pushPathByName('LibraryPage', null);
                  }
                })
              }
              .width('100%')
            }
          }
          .width('92%')
          .margin({ top: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }
}