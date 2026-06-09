import { GlassSurfaceHelper } from '../../ui/material/GlassSurfaceHelper';
import { UiTokens } from '../../ui/tokens/UiTokens';

/** 二级页顶部滚动联动虚化层：仅采样背后 Scroll 内容，不承载导航控件 */
@Component
export struct ScrollLinkedGlassVeil {
  @Prop scrollOffsetY: number = 0;
  @StorageProp('topRectHeight') topInset: number = 0;

  private revealProgress(): number {
    return GlassSurfaceHelper.secondaryGlassProgress(this.scrollOffsetY);
  }

  private veilHeight(): number {
    return this.topInset + UiTokens.HDS_TITLE_BAR_MINI_HEIGHT;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row()
        .width('100%')
        .height(this.veilHeight())
        .backdropBlur(GlassSurfaceHelper.veilBlurRadius(this.revealProgress()))

      Row()
        .width('100%')
        .height(this.veilHeight())
        .backgroundColor(GlassSurfaceHelper.veilMaskColor(this.revealProgress()))
        .opacity(GlassSurfaceHelper.veilMaskOpacity(this.revealProgress()))
    }
    .width('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
