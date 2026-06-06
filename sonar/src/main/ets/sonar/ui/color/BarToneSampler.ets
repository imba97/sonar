import { BarToneStore } from './BarToneStore';
import { ColorUtil } from './ColorUtil';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const COLOR_DEBUG_DOMAIN: number = 0x534E;
const COLOR_DEBUG_TAG: string = 'color-debug';
const COLOR_DEBUG_PREFIX: string = '[color-debug]';

const SAMPLE_INTERVAL_MS: number = 1000;
const PROBE_OVERRIDE_KEY: string = 'barToneProbeOverride';
const SNAPSHOT_SCALE: number = 0.25;
const BOTTOM_BAND_HEIGHT_RATIO: number = 0.14;

export class BarToneSampler {
  private static timer: number = -1;
  private static uiContext: UIContext | undefined = undefined;
  private static sampling: boolean = false;

  static probeId(tabIndex: number): string {
    return `bar-tone-probe-${tabIndex}`;
  }

  static setProbeOverride(probeId: string): void {
    AppStorage.setOrCreate<string>(PROBE_OVERRIDE_KEY, probeId);
  }

  static clearProbeOverride(): void {
    AppStorage.setOrCreate<string>(PROBE_OVERRIDE_KEY, '');
  }

  static start(uiContext: UIContext): void {
    BarToneSampler.stop();
    BarToneSampler.uiContext = uiContext;
    BarToneSampler.timer = setInterval(() => {
      void BarToneSampler.sampleOnce();
    }, SAMPLE_INTERVAL_MS) as number;
    void BarToneSampler.sampleOnce();
  }

  static stop(): void {
    if (BarToneSampler.timer >= 0) {
      clearInterval(BarToneSampler.timer);
      BarToneSampler.timer = -1;
    }
    BarToneSampler.uiContext = undefined;
    BarToneSampler.sampling = false;
  }

  private static resolveProbeId(): string {
    const override: string | undefined = AppStorage.get<string>(PROBE_OVERRIDE_KEY);
    if (override !== undefined && override.length > 0) {
      return override;
    }
    const tabIndex: number = AppStorage.get<number>('rootTabIndex') ?? 0;
    return BarToneSampler.probeId(tabIndex);
  }

  private static async sampleOnce(): Promise<void> {
    if (BarToneSampler.sampling || BarToneSampler.uiContext === undefined) {
      return;
    }
    const rootTabActive: boolean = AppStorage.get<boolean>('rootTabActive') ?? false;
    if (!rootTabActive) {
      return;
    }
    const probeId: string = BarToneSampler.resolveProbeId();
    BarToneSampler.sampling = true;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await BarToneSampler.uiContext.getComponentSnapshot().get(probeId, {
        scale: SNAPSHOT_SCALE,
        waitUntilRenderFinished: true
      });
      const hex: string = await ColorUtil.averageBottomBandFromPixelMap(pixelMap, BOTTOM_BAND_HEIGHT_RATIO);
      BarToneStore.reportBottomSample(hex);
      const toneLabel: string = ColorUtil.isDarkBackground(hex) ? '黑暗' : '明亮';
      hilog.info(
        COLOR_DEBUG_DOMAIN,
        COLOR_DEBUG_TAG,
        '%{public}s 底部颜色类型: %{public}s hex=%{public}s probe=%{public}s',
        COLOR_DEBUG_PREFIX,
        toneLabel,
        hex,
        probeId
      );
    } catch (_err) {
      const tabIndex: number = AppStorage.get<number>('rootTabIndex') ?? 0;
      BarToneStore.resetBaseline(tabIndex, BarToneStore.isDarkMode());
      hilog.warn(
        COLOR_DEBUG_DOMAIN,
        COLOR_DEBUG_TAG,
        '%{public}s 采样失败 probe=%{public}s，已回退基线',
        COLOR_DEBUG_PREFIX,
        probeId
      );
    } finally {
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      BarToneSampler.sampling = false;
    }
  }
}
