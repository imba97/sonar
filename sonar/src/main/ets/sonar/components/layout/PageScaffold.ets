import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct PageScaffold {
  @Prop pageBackground: ResourceColor = Color.Transparent;
  @Prop topPadding: number = 10;
  @Prop bottomPadding: number = 12;
  @Prop applySystemInsets: boolean = true;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.topPadding + (this.applySystemInsets ? this.topInset : 0),
      bottom: this.bottomPadding + (this.applySystemInsets ? this.bottomInset : 0)
    })
    .linearGradient({
      angle: 160,
      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
