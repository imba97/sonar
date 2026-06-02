import { LoginViewModel } from '../viewmodel/LoginViewModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppTextInput } from '../components/forms/AppTextInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'Sonar.LoginPage';

@Component
export struct LoginPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: LoginViewModel = new LoginViewModel();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'LoginPage aboutToAppear');
    void this.vm.restoreRememberedInputs();
    try {
      hilog.info(DOMAIN, TAG, 'vm constructor returned ok, vm=%{public}o', typeof this.vm);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'vm access failed: %{public}s', (err as Error).message);
    }
  }

  build() {
    PageScaffold({
      pageBackground: UiTokens.COLOR_PRIMARY,
      topPadding: 20,
      bottomPadding: 20
    }) {
      Column() {
        // 顶部品牌
        Column() {
          Text('Sonar')
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .letterSpacing(2)
          Text('让自部署音乐，回到你的口袋')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.85)')
            .margin({ top: 8 })
        }
        .margin({ top: 96, bottom: 48 })
        .alignItems(HorizontalAlign.Center)

        Column() {
          CardContainer() {
            Text('登录到你的服务器')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 18 })

            AppTextInput({
              text: this.vm.serverUrl,
              placeholder: '服务器地址 (例: https://navidrome.example.com)',
              onValueChange: (v: string) => {
                this.vm.serverUrl = v;
              }
            })
              .margin({ bottom: 10 })

            AppTextInput({
              text: this.vm.localServerUrl,
              placeholder: '本地 URL (可选，例: http://192.168.1.10:4533)',
              onValueChange: (v: string) => {
                this.vm.localServerUrl = v;
              }
            })
              .margin({ bottom: 10 })

            AppTextInput({
              text: this.vm.username,
              placeholder: '用户名',
              onValueChange: (v: string) => {
                this.vm.username = v;
              }
            })
              .margin({ bottom: 10 })

            AppTextInput({
              text: this.vm.password,
              placeholder: '密码',
              isPassword: true,
              onValueChange: (v: string) => {
                this.vm.password = v;
              }
            })
              .margin({ bottom: 18 })

            PrimaryButton({
              text: '登 录',
              loading: this.vm.isLoading,
              isEnabled: !this.vm.isLoading,
              onPressed: () => {
                this.vm.submit(() => {
                  AppStorage.setOrCreate<number>('rootTabIndex', 0);
                  this.appPathStack.clear();
                });
              }
            })

            if (this.vm.errorMessage.length > 0) {
              Text(this.vm.errorMessage)
                .fontSize(13)
                .fontColor('#D70015')
                .margin({ top: 14 })
                .alignSelf(ItemAlign.Start)
            }
          }
        }
        .width('88%')
        .padding(8)
        .borderRadius(24)
      }
      .width('100%')
    }
  }
}
