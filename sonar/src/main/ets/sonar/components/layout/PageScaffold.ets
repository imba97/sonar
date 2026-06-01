import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct PageScaffold {
  @Prop pageBackground: ResourceColor = UiTokens.COLOR_PAGE_BG;
  @Prop topPadding: number = 10;
  @Prop bottomPadding: number = 12;
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topPadding, bottom: this.bottomPadding })
    .backgroundColor(this.pageBackground)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
