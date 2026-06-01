import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct EmptyState {
  @Prop icon: string = '🎵';
  @Prop title: string = '暂无数据';
  @Prop subtitle: string = '';

  build() {
    Column() {
      Text(this.icon)
        .fontSize(64)
        .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        .margin({ top: 16 })
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(13)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
