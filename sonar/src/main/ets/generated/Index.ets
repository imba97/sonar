import { PageMap } from './detail/SecondPageBuilder'
import { AuthSession } from '../sonar/auth/AuthSession';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlaybackController } from '../sonar/playback/PlaybackController';
import { common } from '@kit.AbilityKit';
import { FloatingTabBar } from '../sonar/components/navigation/FloatingTabBar';
import { UiTokens } from '../sonar/ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'Sonar.Index';
const BACK_PRESS_INTERVAL: number = 2000;

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @State title: string = 'page_title';
  @State private lastBackPressTime: number = 0;

  async aboutToAppear(): Promise<void> {
    await AuthSession.restoreFromStore();
    AppStorage.setOrCreate<number>('rootTabIndex', 0);
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await PlaybackController.initialize(context);
  }

  onBackPress(): boolean {
    // 二级页面：返回上一级
    if (this.appPathStack.size() > 0) {
      hilog.info(DOMAIN, TAG, 'onBackPress: pop destination, stack size=%{public}d', this.appPathStack.size());
      this.appPathStack.pop();
      return true;
    }
    // 一级页面：首次返回提示，二次返回退出
    const now: number = Date.now();
    if (now - this.lastBackPressTime < BACK_PRESS_INTERVAL) {
      hilog.info(DOMAIN, TAG, 'onBackPress: exit app');
      return false; // 2秒内第二次按返回，让系统退出
    }
    this.lastBackPressTime = now;
    hilog.info(DOMAIN, TAG, 'onBackPress: show toast, ask for second press');
    try {
      this.getUIContext().getPromptAction().showToast({ message: '再按一次退出应用', duration: 1500 });
    } catch (_err) {
    }
    return true;
  }

  build() {
    Navigation(this.appPathStack) {
      Column() {
        FloatingTabBar()
      }
      .backgroundColor(Color.Transparent)
      .width('100%')
      .height('100%')
    }
    .navDestination(PageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}