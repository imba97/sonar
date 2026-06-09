import { UiTokens } from '../tokens/UiTokens';

/**
 * 通用 UI 表面毛玻璃参数。
 * 沉浸光感（systemMaterialEffect）在当前 SDK 仅可用于 HdsTabs 等 HDS 配置位点；
 * 卡片/按钮/输入框等 ArkUI 组件在此使用 COMPONENT_THICK 作为统一兜底。
 */
export class GlassSurfaceHelper {
  static readonly BLUR_STYLE: BlurStyle = BlurStyle.COMPONENT_THICK;
  static readonly BLUR_OPTIONS: BackgroundBlurStyleOptions = {
    colorMode: ThemeColorMode.SYSTEM,
    adaptiveColor: AdaptiveColor.DEFAULT,
    scale: 1.0
  };
  /** 二级页滚动联动虚化层最大 backdrop 半径（vp） */
  static readonly VEIL_MAX_BLUR_RADIUS: number = 24;

  static secondaryGlassProgress(scrollOffsetY: number): number {
    const revealVp: number = UiTokens.SECONDARY_GLASS_REVEAL_SCROLL_VP;
    if (scrollOffsetY <= 0 || revealVp <= 0) {
      return 0;
    }
    return Math.min(1, scrollOffsetY / revealVp);
  }

  static veilBlurRadius(progress: number): number {
    const clamped: number = Math.max(0, Math.min(1, progress));
    return clamped * GlassSurfaceHelper.VEIL_MAX_BLUR_RADIUS;
  }

  /** progress=0 全透明；progress>0 使用主题玻璃底色（alpha 由 veilMaskOpacity 缩放） */
  static veilMaskColor(progress: number): ResourceColor {
    if (progress <= 0) {
      return Color.Transparent;
    }
    return UiTokens.COLOR_GLASS_BAR_BG;
  }

  /** 仅缩放蒙层 alpha，不作用于 backdrop 模糊层 */
  static veilMaskOpacity(progress: number): number {
    return Math.max(0, Math.min(1, progress));
  }
}
