import { UiTokens } from '../../ui/tokens/UiTokens';

/** @deprecated 仅经 SonarPageLayout headerSlot 使用；勿在业务页直接引用 */
@Component
export struct FloatingPageTitle {
  @Prop title: string = '';
  @Prop topInset: number = 0;

  build() {
    Row() {
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
      Blank()
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: this.topInset + UiTokens.TAB_PAGE_HEADER_TOP_MARGIN
    })
    .height(UiTokens.TAB_PAGE_HEADER_TITLE_HEIGHT)
    .hitTestBehavior(HitTestMode.None)
  }
}
