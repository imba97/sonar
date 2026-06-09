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

  /** 二级页头部占位：状态栏 + MINI 标题栏 + 底缘冗余 */
  static secondaryHeaderOverlayHeight(topInset: number): number {
    return topInset + UiTokens.SECONDARY_HEADER_OVERLAY_VP;
  }

  /** Tab 根页：官方沉浸式图文，内容顶格穿透标题栏 */
  static primaryContentTopPadding(_topInset: number, _variant: SonarContentVariant = 'form'): number {
    return 0;
  }

  /** 二级页：官方示例 Blank(TITLE_BAR_HEIGHT_MINI)，仅预留 56vp 标题栏占位 */
  static secondaryContentTopPadding(_topInset: number, _variant: SonarContentVariant = 'form'): number {
    return UiTokens.HDS_TITLE_BAR_MINI_HEIGHT;
  }

}
