import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct AppTextInput {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop isPassword: boolean = false;
  @BuilderParam onValueChange: (value: string) => void;

  build() {
    TextInput({ text: this.text, placeholder: this.placeholder })
      .width('100%')
      .height(46)
      .borderRadius(12)
      .backgroundColor('rgba(120,120,128,0.12)')
      .padding({ left: 14, right: 14 })
      .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
      .type(this.isPassword ? InputType.Password : InputType.Normal)
      .onChange((value: string) => {
        if (this.onValueChange !== undefined) {
          this.onValueChange(value);
        }
      })
  }
}
