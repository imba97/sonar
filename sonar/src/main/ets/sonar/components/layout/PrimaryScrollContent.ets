import { ImmersivePageOffsets } from '../../ui/layout/ImmersivePageOffsets';
import { SonarContentVariant } from '../../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Builder
function emptyPrimaryScrollContent() {
}

/** Tab 根页 Scroll 内容边距：沉浸式顶格，底距随 Tab 栏 */
@Component
export struct PrimaryScrollContent {
  @Prop variant: SonarContentVariant = 'form';
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @BuilderParam content: () => void = emptyPrimaryScrollContent;

  private topPadding(): number {
    return ImmersivePageOffsets.primaryContentTopPadding(this.topInset, this.variant);
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
      bottom: ImmersivePageOffsets.tabContentEnd(this.bottomInset, this.rootTabActive)
    })
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
  }
}
