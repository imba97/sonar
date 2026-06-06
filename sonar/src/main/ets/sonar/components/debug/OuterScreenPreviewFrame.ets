import { OuterScreenPlayerPage } from '../../pages/OuterScreenPlayerPage';
import { UiTokens } from '../../ui/tokens/UiTokens';

/**
 * 内屏「外屏预览」专用：深色机身留白 + 居中 1:1 方屏为外屏可视区。
 * 真外屏全屏时不使用本壳层。
 */
@Component
export struct OuterScreenPreviewFrame {
  @State private hostWidth: number = 360;
  @State private hostHeight: number = 780;

  private viewportSize(): number {
    const minHost: number = Math.min(this.hostWidth, this.hostHeight);
    return UiTokens.resolveOuterScreenPreviewViewportVp(minHost);
  }

  private cornerRadius(): number {
    return UiTokens.resolveOuterScreenPreviewCornerRadiusVp(this.viewportSize());
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(UiTokens.OUTER_SCREEN_BEZEL_COLOR)

      Column() {
        OuterScreenPlayerPage()
      }
      .width(this.viewportSize())
      .height(this.viewportSize())
      .borderRadius(this.cornerRadius())
      .clip(true)
      .linearGradient({
        angle: 160,
        colors: [[UiTokens.OUTER_SCREEN_BG_GRADIENT_TOP, 0], [UiTokens.OUTER_SCREEN_BG_GRADIENT_BOTTOM, 1]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(UiTokens.OUTER_SCREEN_BEZEL_COLOR)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldValue, newValue) => {
      if (typeof newValue.width === 'number' && newValue.width > 0) {
        this.hostWidth = newValue.width;
      }
      if (typeof newValue.height === 'number' && newValue.height > 0) {
        this.hostHeight = newValue.height;
      }
    })
  }
}
