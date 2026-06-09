import {
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { FloatingHeaderType, SonarPageLayoutOptions } from '../layout/SonarPageLayoutOptions';
import { ImmersiveMaterialHelper } from './ImmersiveMaterialHelper';
import { UiTokens } from '../tokens/UiTokens';

/** MINI 模式标题栏占位，供二级页 Scroll 穿透 */
export const TITLE_BAR_SCROLL_BLANK_VP: number = UiTokens.HDS_TITLE_BAR_MINI_HEIGHT;

export class HdsTitleBarHelper {
  static buildImmersiveTitleBarStyle(enableScrollEffect: boolean = true): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: enableScrollEffect,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(20)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: Color.Transparent
        },
        contentStyle: {
          backIconStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: Color.Transparent,
          maskExtraHeight: UiTokens.HDS_TITLE_BAR_GRADIENT_MASK_EXTRA
        },
        contentStyle: {
          backIconStyle: {
            backgroundColor: $r('sys.color.comp_background_tertiary'),
            iconColor: $r('sys.color.icon_primary')
          }
        }
      },
      systemMaterialEffect: ImmersiveMaterialHelper.buildNavigationEffect()
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
