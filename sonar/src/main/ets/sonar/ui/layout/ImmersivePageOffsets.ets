import { SonarContentVariant } from './SonarPageLayoutOptions';
import { UiTokens } from '../tokens/UiTokens';

export class ImmersivePageOffsets {
  /** Tab 根页：底栏 + miniBar + 安全区 */
  static tabContentEnd(bottomInset: number, rootTabActive: boolean): number {
    if (rootTabActive) {
      return UiTokens.MINI_PLAYER_TAB_OFFSET + UiTokens.FLOATING_TAB_BAR_HEIGHT + bottomInset +
        UiTokens.LIBRARY_LIST_EDGE_GAP;
    }
    return UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + bottomInset +
      UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 二级页底部安全区 */
  static secondaryContentEnd(bottomInset: number): number {
    return bottomInset + UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 头部占位：状态栏 + MINI 标题栏 + 底缘冗余 */
  static headerOverlayHeight(topInset: number): number {
    return topInset + UiTokens.SECONDARY_HEADER_OVERLAY_VP;
  }

  /** Tab 根页 Scroll 内容顶内边距 */
  static primaryContentTopPadding(topInset: number, variant: SonarContentVariant = 'form'): number {
    const firstLineGap: number = variant === 'hero' ?
      UiTokens.CONTENT_TOP_GAP_HERO : UiTokens.CONTENT_TOP_GAP;
    return ImmersivePageOffsets.headerOverlayHeight(topInset) + firstLineGap;
  }

  /** 二级页 Scroll 内容顶内边距 */
  static secondaryContentTopPadding(topInset: number, variant: SonarContentVariant = 'form'): number {
    return ImmersivePageOffsets.primaryContentTopPadding(topInset, variant);
  }

}
