import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AuthStore } from '../sonar/auth/AuthStore';
import { PlaybackSession } from '../sonar/playback/PlaybackSession';

const DOMAIN = 0x0000;

export default class SonarAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    PlaybackSession.setContext(this.context);

    // 初始化持久化凭据存储
    AuthStore.getInstance().init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'AuthStore init failed: %{public}s', err.message);
    });
  }

  onDestroy(): void {
    void PlaybackSession.release();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('generated/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.setupImmersiveWindow(windowStage);
    });
  }

  private setupImmersiveWindow(windowStage: window.WindowStage): void {
    try {
      const win: window.Window = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'setWindowLayoutFullScreen failed: %{public}s', err.message);
      });
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#FFFFFF'
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'setWindowSystemBarProperties failed: %{public}s', err.message);
      });
      this.updateAvoidAreaInsets(win);
      win.on('avoidAreaChange', () => {
        this.updateAvoidAreaInsets(win);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'setupImmersiveWindow failed: %{public}s', JSON.stringify(err));
    }
  }

  private updateAvoidAreaInsets(win: window.Window): void {
    const density: number = display.getDefaultDisplaySync().densityPixels;
    const topArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const bottomArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const topInset: number = topArea.topRect.height / density;
    const bottomInset: number = bottomArea.bottomRect.height / density;
    AppStorage.setOrCreate<number>('topRectHeight', topInset);
    AppStorage.setOrCreate<number>('bottomRectHeight', bottomInset);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    PlaybackSession.setContext(this.context);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}