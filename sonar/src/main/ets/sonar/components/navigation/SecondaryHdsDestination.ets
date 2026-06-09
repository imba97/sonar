import { HdsNavDestination } from '@kit.UIDesignKit';
import { SonarPageLayout } from '../layout/SonarPageLayout';
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

/** 二级页 HdsNavDestination 路由薄壳（无系统 titleBar，浮层头部由 SonarPageLayout 渲染） */
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
      headerType: FloatingHeaderType.FLOATING_SECONDARY_BAR,
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
    .width('100%')
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
    .systemTransition(NavigationSystemTransitionType.CONTENT)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
