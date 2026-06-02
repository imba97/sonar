import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct TagButton {
  @Prop text: string = '';
  @Prop fontColor: ResourceColor = UiTokens.COLOR_PRIMARY;
  @Prop bgColor: ResourceColor = UiTokens.COLOR_PRIMARY_SOFT_BG;
  @BuilderParam onPressed: () => void;

  build() {
    Button(this.text)
      .height(30)
      .fontSize(12)
      .fontColor(this.fontColor)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.bgColor)
      .borderRadius(UiTokens.RADIUS_CHIP)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        if (this.onPressed !== undefined) {
          this.onPressed();
        }
      })
  }
}
