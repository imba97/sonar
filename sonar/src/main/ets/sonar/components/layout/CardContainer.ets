import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct CardContainer {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding(12)
    .borderRadius(UiTokens.RADIUS_CARD)
    .backgroundColor(UiTokens.COLOR_CARD_BG)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .border({ width: 1, color: UiTokens.COLOR_CARD_BORDER })
  }
}
