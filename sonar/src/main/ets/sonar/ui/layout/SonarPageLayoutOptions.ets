/** 页面在应用中的角色，决定底栏避让与安全区策略 */
export enum SonarPageRole {
  /** Tab 根页：避让 HdsTabs + miniBar */
  TAB_ROOT = 0,
  /** 导航栈二级页：无 Tab 底栏 */
  NAV_STACK = 1,
  /** 独立全屏页（登录等） */
  STANDALONE = 2,
}

/** 浮动头部类型 */
export enum FloatingHeaderType {
  NONE = 0,
  /** 服务器/我的：浮动大标题 */
  FLOATING_TITLE = 1,
  /** 媒体库：搜索栏浮层 */
  FLOATING_SEARCH = 2,
  /** 二级页：HDS MINI 返回+标题+滚动渐变毛玻璃（titleBar 由路由壳配置） */
  HDS_MINI_GRADIENT = 3,
  /** 预留：整栏毛玻璃背板 */
  FULL_GLASS_BAR = 10,
  /** 预留：按滚动阈值显隐毛玻璃 */
  SCROLL_THRESHOLD_GLASS = 11,
}

export type SonarContentVariant = 'form' | 'hero' | 'login';

/** Scroll 由 Layout 包裹，或由业务自管（媒体库 List） */
export enum SonarScrollMode {
  SCROLL = 0,
  CUSTOM_BODY = 1,
}

export interface SonarPageLayoutOptions {
  role: SonarPageRole;
  headerType: FloatingHeaderType;
  headerTitle?: string;
  contentVariant?: SonarContentVariant;
  barToneTabIndex?: number;
  scrollMode?: SonarScrollMode;
  glassRevealOffsetVp?: number;
}
