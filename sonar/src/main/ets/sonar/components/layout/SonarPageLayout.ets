import { FloatingPageContent } from './FloatingPageContent';

import { ScrollLinkedGlassVeil } from '../navigation/ScrollLinkedGlassVeil';
import { SecondaryNavChrome } from '../navigation/SecondaryNavChrome';

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



/** 全站统一：浮动头部 + 可滚动内容 + 浮层 */

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

  @State private scrollOffsetY: number = 0;



  private contentVariant(): SonarContentVariant {

    return this.options.contentVariant ?? 'form';

  }



  private scrollMode(): SonarScrollMode {

    return this.options.scrollMode ?? SonarScrollMode.SCROLL;

  }



  private usesFloatingSecondaryBar(): boolean {

    return this.options.role === SonarPageRole.NAV_STACK &&

      this.options.headerType === FloatingHeaderType.FLOATING_SECONDARY_BAR;

  }



  private syncSecondaryScrollOffset(): void {

    if (!this.usesFloatingSecondaryBar()) {

      return;

    }

    this.scrollOffsetY = Math.max(0, this.scrollerHolder.scroller.currentOffset().yOffset);

  }



  private barToneProbeId(): string {

    const tabIndex: number = this.options.barToneTabIndex ?? -1;

    if (tabIndex >= 0) {

      return `bar-tone-probe-${tabIndex}`;

    }

    return 'bar-tone-probe-inactive';

  }



  aboutToAppear(): void {

    if (this.usesFloatingSecondaryBar()) {

      this.scrollOffsetY = 0;

      this.scrollerHolder.scroller.scrollTo({

        xOffset: 0,

        yOffset: 0,

        animation: false

      });

    }

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

    } else if (this.usesFloatingSecondaryBar()) {

      FloatingPageContent({

        variant: this.contentVariant(),

        underMiniTitleBar: true,

        headerSafeTopInset: this.topInset,

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

      if (this.options.role === SonarPageRole.NAV_STACK) {

        Column() {

          this.buildScrollColumnChildren();

        }

        .width('100%')

        .constraintSize({ minHeight: '100%' })

        .padding({

          bottom: ImmersivePageOffsets.resolveScrollBottomInset(this.options, this.bottomInset, this.rootTabActive)

        })

        .linearGradient({

          angle: 160,

          colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]

        })

      } else {

        Column() {

          this.buildScrollColumnChildren();

        }

        .width('100%')

        .constraintSize({ minHeight: '100%' })

        .padding({

          bottom: ImmersivePageOffsets.resolveScrollBottomInset(this.options, this.bottomInset, this.rootTabActive)

        })

      }

    }

    .width('100%')

    .height('100%')

    .scrollBar(BarState.Off)

    .edgeEffect(EdgeEffect.Spring)

    .onDidScroll((_xOffset: number, _yOffset: number, _scrollState: ScrollState) => {

      this.syncSecondaryScrollOffset();

    })

    .onScrollStop(() => {

      this.syncSecondaryScrollOffset();

    })

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

      } else if (this.usesFloatingSecondaryBar()) {

        ScrollLinkedGlassVeil({ scrollOffsetY: this.scrollOffsetY })

        SecondaryNavChrome({ title: this.options.headerTitle ?? '' })

      }



      this.invokeFloatingLayer()

    }

    .width('100%')

    .height('100%')

  }



  build() {

    if (this.options.role === SonarPageRole.NAV_STACK) {

      Column() {

        this.buildStackBody()

      }

      .width('100%')

      .height('100%')

      .backgroundColor(Color.Transparent)

      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

    } else {

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

}


