import { UiTokens } from '../../ui/tokens/UiTokens';
import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';

@Component
export struct AppTextArea {
  @Prop text: string = '';
  @Prop placeholder: string = '';
  @Prop areaHeight: number = 120;
  @Prop readOnly: boolean = false;
  @BuilderParam onValueChange: (value: string) => void;

  build() {
    Column() {
      TextArea({ text: this.text, placeholder: this.placeholder })
        .width('100%')
        .height('100%')
        .borderRadius(12)
        .backgroundColor(Color.Transparent)
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
        .caretColor(UiTokens.COLOR_PRIMARY)
        .enabled(!this.readOnly)
        .onChange((value: string) => {
          if (!this.readOnly && this.onValueChange !== undefined) {
            this.onValueChange(value);
          }
        })
    }
    .width('100%')
    .height(this.areaHeight)
    .borderRadius(12)
    .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
    .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
    .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
  }
}
