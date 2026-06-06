import { SystemMaterialParams, hdsMaterial } from '@kit.UIDesignKit';
import deviceInfo from '@ohos.deviceInfo';

export enum MaterialSurfaceTier {
  CHROME = 0,
  CONTENT = 1,
  NAVIGATION = 2
}

const HDS_MATERIAL_AVAILABLE_KEY: string = 'hdsMaterialAvailable';

export class ImmersiveMaterialHelper {
  static probeAndCache(): void {
    let available: boolean = false;
    try {
      if (deviceInfo.distributionOSApiVersion >= 60100) {
        const supportedTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
        available = supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
      }
    } catch (_err) {
      available = false;
    }
    AppStorage.setOrCreate<boolean>(HDS_MATERIAL_AVAILABLE_KEY, available);
  }

  static canUseImmersiveMaterial(): boolean {
    return AppStorage.get<boolean>(HDS_MATERIAL_AVAILABLE_KEY) ?? false;
  }

  static buildEffectForTier(tier: MaterialSurfaceTier): SystemMaterialParams | undefined {
    if (!ImmersiveMaterialHelper.canUseImmersiveMaterial()) {
      return undefined;
    }
    if (tier === MaterialSurfaceTier.CONTENT) {
      return {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      };
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }

  static buildNavigationEffect(): SystemMaterialParams {
    if (!ImmersiveMaterialHelper.canUseImmersiveMaterial()) {
      return {
        materialType: hdsMaterial.MaterialType.NONE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH
      };
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }
}
