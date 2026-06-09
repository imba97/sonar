import {
  BlurStrategy,
  HdsNavigationTitleBarOptions,
  HdsTitleBarContentStyle,
  ScrollEffectType,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { FloatingHeaderType, SonarPageLayoutOptions } from '../layout/SonarPageLayoutOptions';

const TITLE_BAR_ORIGINAL_CONTENT_STYLE: HdsTitleBarContentStyle = {
  titleStyle: {
    mainTitleColor: $r('sys.color.font_primary')
  },
  backIconStyle: {
    backgroundColor: Color.Transparent,
    iconColor: $r('sys.color.icon_primary')
  }
};

const TITLE_BAR_SCROLL_CONTENT_STYLE: HdsTitleBarContentStyle = {
  titleStyle: {
    mainTitleColor: $r('sys.color.font_primary')
  },
  backIconStyle: {
    backgroundColor: $r('sys.color.comp_background_tertiary'),
    iconColor: $r('sys.color.icon_primary')
  }
};

export class HdsTitleBarHelper {
  static buildImmersiveTitleBarStyle(enableScrollEffect: boolean = true): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: enableScrollEffect,
        scrollEffectType: ScrollEffectType.COMMON_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(8)
      },
      blurStrategy: BlurStrategy.ENABLE,
      originalStyle: {
        contentStyle: TITLE_BAR_ORIGINAL_CONTENT_STYLE
      },
      scrollEffectStyle: {
        contentStyle: TITLE_BAR_SCROLL_CONTENT_STYLE
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.NONE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      }
    };
  }

  static buildSecondaryTitleBarContent(mainTitle: string): HdsNavigationTitleBarOptions {
    return {
      enableComponentSafeArea: true,
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: mainTitle
        },
        backIcon: {
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true
        }
      },
      style: HdsTitleBarHelper.buildImmersiveTitleBarStyle(true)
    };
  }

  static buildForHeader(options: SonarPageLayoutOptions): HdsNavigationTitleBarOptions | undefined {
    const title: string = options.headerTitle ?? '';
    switch (options.headerType) {
      case FloatingHeaderType.HDS_MINI_GRADIENT:
        return HdsTitleBarHelper.buildSecondaryTitleBarContent(title);
      case FloatingHeaderType.FULL_GLASS_BAR:
      case FloatingHeaderType.SCROLL_THRESHOLD_GLASS:
        return HdsTitleBarHelper.buildSecondaryTitleBarContent(title);
      default:
        return undefined;
    }
  }
}
