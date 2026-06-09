import { PageMap } from './PageMapBuilder';
import { OuterScreenPlayerPage } from './OuterScreenPlayerPage';
import { OuterScreenPreviewFrame } from '../components/debug/OuterScreenPreviewFrame';
import { AuthSession } from '../auth/AuthSession';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlaybackService } from '../playback/PlaybackService';
import { common } from '@kit.AbilityKit';
import { FloatingTabBar } from '../components/navigation/FloatingTabBar';
import { ScreenProfileStore } from '../ui/adaptation/ScreenProfileStore';
import { OuterScreenPalette, OuterScreenTheme } from '../ui/adaptation/OuterScreenTheme';
import { ImmersiveMaterialHelper } from '../ui/material/ImmersiveMaterialHelper';
import { UiTokens } from '../ui/tokens/UiTokens';

const DOMAIN = 0x0000;
const TAG = 'Sonar.Index';
const BACK_PRESS_INTERVAL: number = 2000;

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @StorageLink('screenProfile') @Watch('onScreenProfileChange') screenProfile: string = 'standard';
  @StorageLink('outerScreenPreview') @Watch('onScreenProfileChange') outerScreenPreview: boolean = false;
  @StorageLink('currentColorMode') currentColorMode: number = 0;
  @StorageLink('authPhase') authPhase: string = 'booting';
  @State private lastBackPressTime: number = 0;

  async aboutToAppear(): Promise<void> {
    ScreenProfileStore.ensureInitialized();
    ImmersiveMaterialHelper.probeAndCache();
    await AuthSession.bootstrap();
    AppStorage.setOrCreate<number>('rootTabIndex', 0);
    ScreenProfileStore.refreshProfile();
    this.maybeRedirectToLogin();
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await PlaybackService.initialize(context);
  }

  private isOuterUiActive(): boolean {
    return this.outerScreenPreview || this.screenProfile === 'outer';
  }

  private maybeRedirectToLogin(): void {
    if (this.isOuterUiActive()) {
      return;
    }
    if (this.authPhase !== 'anonymous') {
      return;
    }
    this.appPathStack.replacePathByName('LoginPage', null);
  }

  private onScreenProfileChange(): void {
    hilog.info(DOMAIN, TAG, 'uiMode preview=%{public}s profile=%{public}s',
      this.outerScreenPreview ? 'true' : 'false', this.screenProfile);
    if (this.isOuterUiActive()) {
      return;
    }
    this.maybeRedirectToLogin();
  }

  onBackPress(): boolean {
    if (this.outerScreenPreview) {
      ScreenProfileStore.setPreviewEnabled(false);
      return true;
    }
    if (!this.isOuterUiActive() && this.appPathStack.size() > 0) {
      hilog.info(DOMAIN, TAG, 'onBackPress: pop destination, stack size=%{public}d', this.appPathStack.size());
      this.appPathStack.pop();
      return true;
    }
    const now: number = Date.now();
    if (now - this.lastBackPressTime < BACK_PRESS_INTERVAL) {
      hilog.info(DOMAIN, TAG, 'onBackPress: exit app');
      return false;
    }
    this.lastBackPressTime = now;
    hilog.info(DOMAIN, TAG, 'onBackPress: show toast, ask for second press');
    try {
      this.getUIContext().getPromptAction().showToast({ message: '再按一次退出应用', duration: 1500 });
    } catch (_err) {
    }
    return true;
  }

  @Builder
  private buildStandardApp() {
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

  private outerScreenPalette(): OuterScreenPalette {
    const isDark: boolean = OuterScreenTheme.isDarkUi(this.currentColorMode);
    return OuterScreenTheme.palette(isDark);
  }

  @Builder
  private buildOuterScreenApp() {
    if (this.outerScreenPreview) {
      OuterScreenPreviewFrame()
    } else {
      Column() {
        OuterScreenPlayerPage()
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 160,
        colors: [[this.outerScreenPalette().bgGradientTop, 0], [this.outerScreenPalette().bgGradientBottom, 1]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  build() {
    if (this.outerScreenPreview || this.screenProfile === 'outer') {
      this.buildOuterScreenApp()
    } else {
      this.buildStandardApp()
    }
  }
}
