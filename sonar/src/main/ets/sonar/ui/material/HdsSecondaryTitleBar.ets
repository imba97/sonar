import {
  HdsNavigationTitleBarOptions,
  HdsTitleBarContentStyle,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { UiTokens } from '../tokens/UiTokens';

const SECONDARY_TITLE_BAR_CONTENT_STYLE: HdsTitleBarContentStyle = {
  titleStyle: {
    mainTitleColor: $r('sys.color.font_primary')
  },
  backIconStyle: {
    backgroundColor: Color.Transparent,
    iconColor: $r('sys.color.icon_primary')
  }
};

/** 二级页 HdsNavDestination 标题栏：官方 COMMON_BLUR 骨架，静止透明背板 */
export class HdsSecondaryTitleBar {
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
        contentStyle: SECONDARY_TITLE_BAR_CONTENT_STYLE
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
        },
        contentStyle: SECONDARY_TITLE_BAR_CONTENT_STYLE
      }
    };
  }

  static build(mainTitle: string): HdsNavigationTitleBarOptions {
    return {
      // ignoreLayoutSafeArea 沉浸布局下，标题栏主动避让状态栏（仅布局高度，不影响 COMMON_BLUR）
      avoidLayoutSafeArea: true,
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: HdsSecondaryTitleBar.buildTitleBarStyle(),
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
