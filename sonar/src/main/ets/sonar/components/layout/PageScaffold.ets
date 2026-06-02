import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct PageScaffold {
  @Prop pageBackground: ResourceColor = Color.Transparent;
  @Prop topPadding: number = 10;
  @Prop bottomPadding: number = 12;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding + this.topInset, bottom: this.bottomPadding + this.bottomInset })
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
