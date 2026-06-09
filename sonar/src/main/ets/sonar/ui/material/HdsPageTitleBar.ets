import {
  HdsNavigationTitleBarOptions,
  ScrollEffectType,
  TitleBarStyleOptions
} from '@kit.UIDesignKit';
import { ImmersiveMaterialHelper } from './ImmersiveMaterialHelper';

/** 全站 HDS 标题栏：对齐官方 IMMERSIVE_GRADIENT_BLUR + systemMaterialEffect 示例 */
export class HdsPageTitleBar {
  static buildTitleBarStyle(): TitleBarStyleOptions {
    return {
      scrollEffectOpts: {
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
      },
      systemMaterialEffect: ImmersiveMaterialHelper.buildTitleBarEffect()
    };
  }

  /** Tab 根页：空标题栏（无返回、无标题） */
  static buildPrimary(): HdsNavigationTitleBarOptions {
    return {
      style: HdsPageTitleBar.buildTitleBarStyle()
    };
  }

  /** 二级页：返回 + 标题 */
  static buildSecondary(mainTitle: string): HdsNavigationTitleBarOptions {
    return {
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
