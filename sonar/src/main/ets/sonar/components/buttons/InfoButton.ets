import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct InfoButton {
  @Prop text: string = '';
  @BuilderParam onPressed: () => void;

  build() {
    Button(this.text)
      .height(30)
      .fontSize(12)
      .fontColor(UiTokens.COLOR_INFO)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(UiTokens.COLOR_INFO_SOFT_BG)
      .borderRadius(UiTokens.RADIUS_CHIP)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        if (this.onPressed !== undefined) {
          this.onPressed();
        }
      })
  }
}
