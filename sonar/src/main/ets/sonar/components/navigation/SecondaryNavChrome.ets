import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';
import { UiTokens } from '../../ui/tokens/UiTokens';

/** 二级页导航浮层：玻璃返回键 + 标题，不承担顶部大面积虚化 */
@Component
export struct SecondaryNavChrome {
  @Prop title: string = '';
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('topRectHeight') topInset: number = 0;

  private handleBackNavigation(): void {
    if (this.appPathStack.size() > 0) {
      this.appPathStack.pop();
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('sys.color.icon_primary')])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .borderRadius(20)
        .backgroundBlurStyle(GlassSurfaceHelper.BLUR_STYLE, GlassSurfaceHelper.BLUR_OPTIONS)
        .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
        .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
        .onClick(() => {
          this.handleBackNavigation();
        })

        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(UiTokens.HDS_TITLE_BAR_MINI_HEIGHT)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: this.topInset })
  }
}
