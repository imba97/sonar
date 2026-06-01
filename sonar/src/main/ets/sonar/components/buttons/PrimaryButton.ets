import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct PrimaryButton {
  @Prop text: string = '';
  @Prop isEnabled: boolean = true;
  @Prop loading: boolean = false;
  @BuilderParam onPressed: () => void;

  build() {
    Button(this.loading ? '处理中…' : this.text)
      .width('100%')
      .height(48)
      .fontSize(16)
      .fontColor(Color.White)
      .fontWeight(FontWeight.Medium)
      .borderRadius(UiTokens.RADIUS_BUTTON)
      .backgroundColor(this.isEnabled && !this.loading ? UiTokens.COLOR_PRIMARY : 'rgba(10,132,255,0.55)')
      .enabled(this.isEnabled && !this.loading)
      .onClick(() => {
        if (this.isEnabled && !this.loading) {
          if (this.onPressed !== undefined) {
            this.onPressed();
          }
        }
      })
  }
}
