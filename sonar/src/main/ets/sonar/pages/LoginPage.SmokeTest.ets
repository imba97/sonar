/*
 * Smoke-test version of LoginPage.
 *
 * Purpose: isolate whether the blank-screen issue is caused by:
 *   (a) PageMap routing not reaching the LoginPage branch, or
 *   (b) something inside LoginPage's build() (e.g. bindings, ViewModel, or
 *       a chained ArkUI attribute) failing silently.
 *
 * If this minimal version renders when used in place of the real LoginPage,
 * the problem is in the real LoginPage (likely the chained .backgroundColor
 * attribute or a ViewModel binding).
 * If this minimal version also renders blank, the problem is upstream
 * (PageMap routing, Navigation stack, or @Consume context).
 *
 * To activate: in `SecondPageBuilder.ets`, swap the LoginPage import and
 * the `LoginPage()` call to point at this file, rebuild, and re-run.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'Sonar.LoginPage.Smoke';

@Component
export struct LoginPageSmoke {
  @Consume('appPathStack') appPathStack: NavPathStack;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'SmokeTest aboutToAppear');
  }

  build() {
    hilog.info(DOMAIN, TAG, 'SmokeTest build() called');
    Column() {
      Text('LOGIN SMOKE TEST')
        .fontSize(24)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Bold)
      Text('If you can read this, routing + @Consume both work.')
        .fontSize(14)
        .fontColor('rgba(255,255,255,0.85)')
        .margin({ top: 12 })
      Button('Back')
        .margin({ top: 24 })
        .onClick(() => {
          this.appPathStack.pop();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A84FF')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
