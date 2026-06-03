import { SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';

export class ImmersiveMaterialHelper {
  static resolveMaterialLevel(): hdsMaterial.MaterialLevel {
    // style.mdc: 默认 ADAPTIVE，若设备不支持 IMMERSIVE，降级到 SMOOTH 以保证性能与稳定性。
    let level: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;
    try {
      const supportedTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      if (supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
        level = hdsMaterial.MaterialLevel.SMOOTH;
      }
    } catch (_err) {
      level = hdsMaterial.MaterialLevel.SMOOTH;
    }
    return level;
  }

  static buildAdaptiveEffect(level: hdsMaterial.MaterialLevel): SystemMaterialParams {
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: level
    };
  }
}
