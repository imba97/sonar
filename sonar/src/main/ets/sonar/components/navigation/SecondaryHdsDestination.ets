import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SonarScrollContent } from '../layout/SonarScrollContent';
import { HdsPageTitleBar } from '../../ui/material/HdsPageTitleBar';
import { SonarContentVariant, SonarPageRole } from '../../ui/layout/SonarPageLayoutOptions';

@Builder
function emptySecondaryContent() {
}

@Builder
function emptySecondaryFloatingLayer() {
}

/** 二级页：HdsNavDestination 直包 Scroll + IMMERSIVE_GRADIENT_BLUR + bindToScrollable（官方骨架） */
@Component
export struct SecondaryHdsDestination {
  @Prop title: string = '';
  @Prop contentVariant: SonarContentVariant = 'form';
  private scroller: Scroller = new Scroller();
  @BuilderParam content: () => void = emptySecondaryContent;
  @BuilderParam floatingLayer: () => void = emptySecondaryFloatingLayer;

  @LocalBuilder
  buildScrollContent() {
    SonarScrollContent({
      role: SonarPageRole.NAV_STACK,
      variant: this.contentVariant,
      content: this.content
    });
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.scroller) {
          this.buildScrollContent();
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        this.floatingLayer();
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .hideTitleBar(false)
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(HdsPageTitleBar.buildSecondary(this.title))
    .bindToScrollable([this.scroller])
    .backgroundColor(Color.Transparent)
    .systemTransition(NavigationSystemTransitionType.CONTENT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
