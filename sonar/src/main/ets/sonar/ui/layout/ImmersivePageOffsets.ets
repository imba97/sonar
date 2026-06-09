import { FloatingHeaderType, SonarPageLayoutOptions, SonarPageRole } from './SonarPageLayoutOptions';
import { UiTokens } from '../tokens/UiTokens';

export class ImmersivePageOffsets {
  /** Tab 根页：状态栏 + 浮层标题/搜索区 */
  static tabContentStart(topInset: number, headerOverlayVp: number): number {
    return topInset + headerOverlayVp;
  }

  /** Tab 根页浮层大标题（服务器/我的） */
  static tabFloatingTitleStart(topInset: number): number {
    return ImmersivePageOffsets.tabContentStart(topInset, UiTokens.TAB_PAGE_HEADER_OVERLAY_VP);
  }

  /** Tab 根页：底栏 + miniBar + 安全区 */
  static tabContentEnd(bottomInset: number, rootTabActive: boolean): number {
    if (rootTabActive) {
      return UiTokens.MINI_PLAYER_TAB_OFFSET + UiTokens.FLOATING_TAB_BAR_HEIGHT + bottomInset +
        UiTokens.LIBRARY_LIST_EDGE_GAP;
    }
    return UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + bottomInset +
      UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 二级页 Scroll 穿透 MINI 标题栏（不含状态栏，由 titleBar 安全区处理） */
  static secondaryScrollTopBlank(): number {
    return UiTokens.HDS_TITLE_BAR_MINI_HEIGHT;
  }

  /** 二级页底部安全区 */
  static secondaryContentEnd(bottomInset: number): number {
    return bottomInset + UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** SonarPageLayout：Scroll 内容区顶部占位/内边距 */
  static resolveScrollTopInset(options: SonarPageLayoutOptions, topInset: number): number {
    if (options.role === SonarPageRole.NAV_STACK) {
      return ImmersivePageOffsets.secondaryScrollTopBlank();
    }
    if (options.role === SonarPageRole.TAB_ROOT &&
      options.headerType === FloatingHeaderType.FLOATING_TITLE) {
      return ImmersivePageOffsets.tabFloatingTitleStart(topInset);
    }
    return 0;
  }

  /** SonarPageLayout：Scroll 内容区底部内边距 */
  static resolveScrollBottomInset(options: SonarPageLayoutOptions, bottomInset: number,
    rootTabActive: boolean): number {
    if (options.role === SonarPageRole.TAB_ROOT) {
      return ImmersivePageOffsets.tabContentEnd(bottomInset, rootTabActive);
    }
    if (options.role === SonarPageRole.NAV_STACK) {
      return ImmersivePageOffsets.secondaryContentEnd(bottomInset);
    }
    return bottomInset + UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  /** 媒体库 List contentStartOffset */
  static libraryListStartOffset(topInset: number): number {
    return ImmersivePageOffsets.tabContentStart(topInset,
      UiTokens.LIBRARY_SEARCH_TOP_MARGIN + UiTokens.LIBRARY_SEARCH_HEIGHT + UiTokens.LIBRARY_SEARCH_CONTENT_GAP);
  }
}
