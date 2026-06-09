/** 页面在应用中的角色，决定底栏避让与安全区策略 */
export enum SonarPageRole {
  /** Tab 根页：避让 HdsTabs + miniBar */
  TAB_ROOT = 0,
  /** 独立全屏页（登录等） */
  STANDALONE = 1,
}

export type SonarContentVariant = 'form' | 'hero' | 'login';

/** Scroll 由 Layout 包裹，或由业务自管（媒体库 List） */
export enum SonarScrollMode {
  SCROLL = 0,
  CUSTOM_BODY = 1,
}

export interface SonarPageLayoutOptions {
  role: SonarPageRole;
  contentVariant?: SonarContentVariant;
  barToneTabIndex?: number;
  scrollMode?: SonarScrollMode;
}
