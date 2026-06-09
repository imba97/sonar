import { ImmersivePageOffsets } from '../../ui/layout/ImmersivePageOffsets';
import { SonarContentVariant } from '../../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Builder
function emptySecondaryScrollContent() {
}

/** 二级页 Scroll 内容边距：仅水平/顶底间距，不处理标题栏模糊 */
@Component
export struct SecondaryScrollContent {
  @Prop variant: SonarContentVariant = 'form';
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @BuilderParam content: () => void = emptySecondaryScrollContent;

  private topPadding(): number {
    return ImmersivePageOffsets.secondaryContentTopPadding(this.topInset, this.variant);
  }

  build() {
    Column({ space: UiTokens.SECTION_GAP }) {
      this.content()
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .padding({
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING,
      top: this.topPadding(),
      bottom: ImmersivePageOffsets.secondaryContentEnd(this.bottomInset)
    })
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
  }
}
