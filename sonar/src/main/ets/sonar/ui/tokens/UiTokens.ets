export class UiTokens {
  static readonly TAB_BAR_CONTENT_EXTRA_PADDING: number = 16;

  static readonly COLOR_PRIMARY: ResourceColor = $r('app.color.sonar_primary');
  static readonly COLOR_INFO: ResourceColor = $r('app.color.sonar_info');
  static readonly COLOR_SUCCESS: ResourceColor = $r('app.color.sonar_success');
  static readonly COLOR_DANGER: ResourceColor = $r('app.color.sonar_danger');
  static readonly COLOR_WARNING: ResourceColor = $r('app.color.sonar_warning');

  static readonly COLOR_BG_GRADIENT_TOP: ResourceColor = $r('app.color.sonar_bg_gradient_top');
  static readonly COLOR_BG_GRADIENT_BOTTOM: ResourceColor = $r('app.color.sonar_bg_gradient_bottom');
  static readonly COLOR_PAGE_BG: ResourceColor = $r('app.color.sonar_page_bg');

  static readonly COLOR_TEXT_PRIMARY: ResourceColor = $r('app.color.sonar_text_primary');
  static readonly COLOR_TEXT_SECONDARY: ResourceColor = $r('app.color.sonar_text_secondary');
  static readonly COLOR_TEXT_TERTIARY: ResourceColor = $r('app.color.sonar_text_tertiary');

  static readonly COLOR_CARD_BG: ResourceColor = $r('app.color.sonar_card_bg');
  static readonly COLOR_CARD_BORDER: ResourceColor = $r('app.color.sonar_card_border');
  static readonly COLOR_PLACEHOLDER_BG: ResourceColor = $r('app.color.sonar_placeholder_bg');
  static readonly COLOR_GLASS_BAR_BG: ResourceColor = $r('app.color.sonar_glass_bar_bg');
  static readonly COLOR_GLASS_BAR_BORDER: ResourceColor = $r('app.color.sonar_glass_bar_border');

  static readonly COLOR_PRIMARY_SOFT_BG: ResourceColor = $r('app.color.sonar_primary_soft_bg');
  static readonly COLOR_INFO_SOFT_BG: ResourceColor = $r('app.color.sonar_info_soft_bg');
  static readonly COLOR_SUCCESS_SOFT_BG: ResourceColor = $r('app.color.sonar_success_soft_bg');
  static readonly COLOR_WARNING_SOFT_BG: ResourceColor = $r('app.color.sonar_warning_soft_bg');
  static readonly COLOR_DANGER_SOFT_BG: ResourceColor = $r('app.color.sonar_danger_soft_bg');
  static readonly COLOR_TAB_ICON_INACTIVE: ResourceColor = $r('app.color.sonar_tab_icon_inactive');
  static readonly COLOR_OVERLAY_SCRIM: ResourceColor = $r('app.color.sonar_overlay_scrim');
  static readonly COLOR_DROPDOWN_TITLE: ResourceColor = $r('app.color.sonar_dropdown_title');
  static readonly COLOR_DROPDOWN_PANEL_BG: ResourceColor = $r('app.color.sonar_dropdown_panel_bg');
  static readonly COLOR_INPUT_BG: ResourceColor = $r('app.color.sonar_input_bg');
  static readonly COLOR_TEXT_ON_BRAND: ResourceColor = $r('app.color.sonar_text_on_brand');
  static readonly COLOR_TEXT_ON_BRAND_SECONDARY: ResourceColor = $r('app.color.sonar_text_on_brand_secondary');
  static readonly COLOR_SUCCESS_ALT: ResourceColor = $r('app.color.sonar_success_alt');
  static readonly COLOR_PRIMARY_DISABLED_BG: ResourceColor = $r('app.color.sonar_primary_disabled_bg');
  static readonly COLOR_ERROR: ResourceColor = $r('app.color.sonar_error');

  static readonly RADIUS_BUTTON: number = 14;
  static readonly RADIUS_CARD: number = 14;
  static readonly RADIUS_CHIP: number = 15;

  static readonly FLOATING_TAB_BAR_HEIGHT: number = 56;
  static readonly FLOATING_TAB_BAR_BOTTOM_MARGIN: number = 10;
  /** 展开底栏总宽（页签+mini）：唯一调节点；见 .cursor/rules/hds/tabs-bar-floating.mdc「展开底部胶囊宽度」 */
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_SMALL: number = 262;
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_MEDIUM: number = 278;
  static readonly FLOATING_TAB_BAR_EXPANDED_WIDTH_LARGE: number = 294;
  static readonly DOCK_COVER_ROTATION_DURATION: number = 9000;
  static readonly MINI_BAR_BALL_COVER_INSET: number = 6;
  static readonly MINI_PLAYER_CAPSULE_CONTENT_GAP: number = 10;
  static readonly MINI_PLAYER_ACTION_TOUCH_SIZE: number = 34;
  static readonly MINI_PLAYER_ACTION_ICON_GAP: number = 6;
  static readonly BOTTOM_PADDING_WITH_TAB_BAR: number =
    UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN +
    UiTokens.TAB_BAR_CONTENT_EXTRA_PADDING;
  static readonly MINI_PLAYER_TAB_OFFSET: number =
    UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + 12;
  static readonly MINI_PLAYER_BOTTOM_PADDING: number = 92;
  static readonly MINI_PLAYER_WITH_TAB_BOTTOM_PADDING: number = 96;

  static readonly LIBRARY_SEARCH_TOP_MARGIN: number = 10;
  static readonly LIBRARY_SEARCH_HEIGHT: number = 48;
  static readonly LIBRARY_SEARCH_SIDE_PADDING: number = 18;
  static readonly LIBRARY_SEARCH_CONTENT_GAP: number = 8;
  static readonly LIBRARY_PAGE_HORIZONTAL_PADDING: number = 14;
  static readonly LIBRARY_LIST_EDGE_GAP: number = 8;
  static readonly LIBRARY_GRID_GAP: number = 12;
  static readonly LIBRARY_CARD_MIN_WIDTH: number = 180;
  static readonly LIBRARY_CARD_COVER_HEIGHT: number = 146;
  static readonly LIBRARY_CARD_TITLE_HEIGHT: number = 22;
}
