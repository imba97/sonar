import {
  HdsNavigationTitleBarOptions,
  HdsTitleBarContentStyle,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { UiTokens } from '../tokens/UiTokens';

const PAGE_TITLE_BAR_CONTENT_STYLE: HdsTitleBarContentStyle = {
  titleStyle: {
    mainTitleColor: $r('sys.color.font_primary')
  },
  backIconStyle: {
    backgroundColor: Color.Transparent,
    iconColor: $r('sys.color.icon_primary')
  }
};

/** 全站 HDS 标题栏：官方 COMMON_BLUR 骨架，静止透明背板 */
export class HdsPageTitleBar {
  static buildTitleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.COMMON_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(UiTokens.SECONDARY_GLASS_REVEAL_SCROLL_VP)
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: Color.Transparent
        },
        contentStyle: PAGE_TITLE_BAR_CONTENT_STYLE
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
        },
        contentStyle: PAGE_TITLE_BAR_CONTENT_STYLE
      }
    };
  }

  private static baseOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: HdsPageTitleBar.buildTitleBarStyle()
    };
  }

  /** Tab 根页：空标题栏（无返回、无标题） */
  static buildPrimary(): HdsNavigationTitleBarOptions {
    return HdsPageTitleBar.baseOptions();
  }

  /** 二级页：返回 + 标题 */
  static buildSecondary(mainTitle: string): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: HdsPageTitleBar.buildTitleBarStyle(),
      content: {
        title: {
          mainTitle: mainTitle
        },
        backIcon: {
          icon: $r('sys.symbol.chevron_left'),
          isEnabled: true
        }
      }
    };
  }
}
