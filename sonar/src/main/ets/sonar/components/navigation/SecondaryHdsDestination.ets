import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SonarPageLayout } from '../layout/SonarPageLayout';
import { HdsTitleBarHelper } from '../../ui/material/HdsTitleBarHelper';
import { SonarPageScrollerHolder } from '../../ui/layout/SonarPageScrollerHolder';
import {
  FloatingHeaderType,
  SonarContentVariant,
  SonarPageLayoutOptions,
  SonarPageRole,
  SonarScrollMode
} from '../../ui/layout/SonarPageLayoutOptions';

@Builder
function emptySecondaryContent() {
}

@Builder
function emptySecondaryFloatingLayer() {
}

/** 二级页 HdsNavDestination 路由薄壳 */
@Component
export struct SecondaryHdsDestination {
  @Prop title: string = '';
  @Prop contentVariant: SonarContentVariant = 'form';
  @Provide('sonarPageScrollerHolder') scrollerHolder: SonarPageScrollerHolder = new SonarPageScrollerHolder();
  @BuilderParam content: () => void = emptySecondaryContent;
  @BuilderParam floatingLayer: () => void = emptySecondaryFloatingLayer;

  private layoutOptions(): SonarPageLayoutOptions {
    return {
      role: SonarPageRole.NAV_STACK,
      headerType: FloatingHeaderType.HDS_MINI_GRADIENT,
      headerTitle: this.title,
      contentVariant: this.contentVariant,
      scrollMode: SonarScrollMode.SCROLL
    };
  }

  @LocalBuilder
  buildLayoutContent() {
    this.content();
  }

  @LocalBuilder
  buildLayoutFloatingLayer() {
    this.floatingLayer();
  }

  build() {
    HdsNavDestination() {
      SonarPageLayout({
        options: this.layoutOptions(),
        content: this.buildLayoutContent,
        floatingLayer: this.buildLayoutFloatingLayer
      })
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar(HdsTitleBarHelper.buildForHeader(this.layoutOptions()))
    .bindToScrollable([this.scrollerHolder.scroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
