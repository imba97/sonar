export class UiTokens {
  static readonly TAB_BAR_CONTENT_EXTRA_PADDING: number = 16;
  static readonly MINI_PLAYER_TAB_EXTRA_OFFSET: number = 8;

  static readonly COLOR_PRIMARY: string = '#0A84FF';
  static readonly COLOR_INFO: string = '#5AC8FA';
  static readonly COLOR_SUCCESS: string = '#30D158';
  static readonly COLOR_DANGER: string = 'rgba(255,69,58,1)';
  static readonly COLOR_WARNING: string = '#FF9F0A';

  static readonly COLOR_BG_GRADIENT_TOP: string = '#21222B';
  static readonly COLOR_BG_GRADIENT_BOTTOM: string = '#121317';
  static readonly COLOR_PAGE_BG: string = '#121317';

  static readonly COLOR_TEXT_PRIMARY: string = '#F2F3F5';
  static readonly COLOR_TEXT_SECONDARY: string = 'rgba(235,235,245,0.62)';
  static readonly COLOR_TEXT_TERTIARY: string = 'rgba(235,235,245,0.40)';

  static readonly COLOR_CARD_BG: string = 'rgba(255,255,255,0.07)';
  static readonly COLOR_CARD_BORDER: string = 'rgba(255,255,255,0.12)';
  static readonly COLOR_PLACEHOLDER_BG: string = 'rgba(255,255,255,0.10)';
  static readonly COLOR_GLASS_BAR_BG: string = 'rgba(26,27,33,0.55)';
  static readonly COLOR_GLASS_BAR_BORDER: string = 'rgba(255,255,255,0.14)';

  static readonly COLOR_PRIMARY_SOFT_BG: string = 'rgba(10,132,255,0.20)';
  static readonly COLOR_INFO_SOFT_BG: string = 'rgba(90,200,250,0.20)';
  static readonly COLOR_SUCCESS_SOFT_BG: string = 'rgba(48,209,88,0.20)';
  static readonly COLOR_WARNING_SOFT_BG: string = 'rgba(255,159,10,0.20)';
  static readonly COLOR_DANGER_SOFT_BG: string = 'rgba(255,69,58,0.20)';

  static readonly RADIUS_BUTTON: number = 14;
  static readonly RADIUS_CARD: number = 14;
  static readonly RADIUS_CHIP: number = 15;

  static readonly TAB_BAR_ICON_SIZE: number = 26;
  static readonly TAB_BAR_ICON_GAP: number = 24;
  static readonly FLOATING_TAB_BAR_HEIGHT: number = 56;
  static readonly FLOATING_TAB_BAR_COMPACT_WIDTH: number = 168;
  static readonly FLOATING_TAB_BAR_BOTTOM_MARGIN: number = 10;
  static readonly BOTTOM_PADDING_WITH_TAB_BAR: number =
    UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN +
    UiTokens.TAB_BAR_CONTENT_EXTRA_PADDING;
  static readonly MINI_PLAYER_BASE_MARGIN_BOTTOM: number = 8;
  static readonly MINI_PLAYER_TAB_OFFSET: number =
    UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN +
    UiTokens.MINI_PLAYER_TAB_EXTRA_OFFSET;
  static readonly MINI_PLAYER_BOTTOM_PADDING: number = 92;
  static readonly MINI_PLAYER_WITH_TAB_BOTTOM_PADDING: number = 166;
}
