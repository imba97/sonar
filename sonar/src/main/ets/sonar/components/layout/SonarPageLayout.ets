import { FloatingPageContent } from './FloatingPageContent';

import { ImmersivePageOffsets } from '../../ui/layout/ImmersivePageOffsets';

import {

  FloatingHeaderType,

  SonarContentVariant,

  SonarPageLayoutOptions,

  SonarPageRole,

  SonarScrollMode

} from '../../ui/layout/SonarPageLayoutOptions';

import { SonarPageScrollerHolder } from '../../ui/layout/SonarPageScrollerHolder';

import { UiTokens } from '../../ui/tokens/UiTokens';



@Builder

function emptySonarHeaderSlot() {

}



@Builder

function emptySonarFloatingLayer() {

}



@Builder

function emptySonarPageContent() {

}



/** 全站统一：浮动头部 + 可滚动内容 + 浮层（Tab 根页 / 独立页） */

@Component

export struct SonarPageLayout {

  @Prop options: SonarPageLayoutOptions = {

    role: SonarPageRole.TAB_ROOT,

    headerType: FloatingHeaderType.NONE,

    contentVariant: 'form',

    scrollMode: SonarScrollMode.SCROLL

  };

  @BuilderParam content: () => void = emptySonarPageContent;

  @BuilderParam headerSlot: () => void = emptySonarHeaderSlot;

  @BuilderParam floatingLayer: () => void = emptySonarFloatingLayer;

  @Consume('sonarPageScrollerHolder') scrollerHolder: SonarPageScrollerHolder = new SonarPageScrollerHolder();

  @StorageProp('topRectHeight') topInset: number = 0;

  @StorageProp('bottomRectHeight') bottomInset: number = 0;

  @StorageLink('rootTabActive') rootTabActive: boolean = false;



  private contentVariant(): SonarContentVariant {

    return this.options.contentVariant ?? 'form';

  }



  private scrollMode(): SonarScrollMode {

    return this.options.scrollMode ?? SonarScrollMode.SCROLL;

  }



  private barToneProbeId(): string {

    const tabIndex: number = this.options.barToneTabIndex ?? -1;

    if (tabIndex >= 0) {

      return `bar-tone-probe-${tabIndex}`;

    }

    return 'bar-tone-probe-inactive';

  }



  @LocalBuilder

  invokePageContent() {

    this.content();

  }



  @LocalBuilder

  invokeHeaderSlot() {

    this.headerSlot();

  }



  @LocalBuilder

  invokeFloatingLayer() {

    this.floatingLayer();

  }



  @LocalBuilder

  buildWrappedContent() {

    if (this.options.role === SonarPageRole.STANDALONE) {

      FloatingPageContent({

        variant: this.contentVariant(),

        applySectionGap: false,

        content: this.invokePageContent

      });

    } else if (this.options.role === SonarPageRole.TAB_ROOT &&

      this.options.headerType === FloatingHeaderType.NONE) {

      this.invokePageContent();

    } else if (this.options.role === SonarPageRole.TAB_ROOT &&

      this.options.headerType === FloatingHeaderType.FLOATING_TITLE) {

      FloatingPageContent({

        variant: 'form',

        applyTopGap: false,

        applySectionGap: false,

        content: this.invokePageContent

      });

    } else {

      FloatingPageContent({

        variant: this.contentVariant(),

        content: this.invokePageContent

      });

    }

  }



  @LocalBuilder

  buildScrollColumnChildren() {

    if (ImmersivePageOffsets.resolveScrollTopInset(this.options, this.topInset) > 0) {

      Blank()

        .width('100%')

        .height(ImmersivePageOffsets.resolveScrollTopInset(this.options, this.topInset))

    }

    this.buildWrappedContent();

  }



  @Builder

  private buildScrollBody() {

    Scroll(this.scrollerHolder.scroller) {

      Column() {

        this.buildScrollColumnChildren();

      }

      .width('100%')

      .constraintSize({ minHeight: '100%' })

      .padding({

        bottom: ImmersivePageOffsets.resolveScrollBottomInset(this.options, this.bottomInset, this.rootTabActive)

      })

    }

    .width('100%')

    .height('100%')

    .scrollBar(BarState.Off)

    .edgeEffect(EdgeEffect.Spring)

  }



  @Builder

  private buildStackBody() {

    Stack({ alignContent: Alignment.Top }) {

      if (this.scrollMode() === SonarScrollMode.CUSTOM_BODY) {

        this.invokePageContent()

      } else {

        this.buildScrollBody()

      }



      if (this.options.headerType === FloatingHeaderType.FLOATING_TITLE ||

        this.options.headerType === FloatingHeaderType.FLOATING_SEARCH) {

        this.invokeHeaderSlot()

      }



      this.invokeFloatingLayer()

    }

    .width('100%')

    .height('100%')

  }



  build() {

    Column() {

      this.buildStackBody()

    }

    .width('100%')

    .height('100%')

    .linearGradient({

      angle: 160,

      colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]

    })

    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    .id(this.barToneProbeId())

  }

}

