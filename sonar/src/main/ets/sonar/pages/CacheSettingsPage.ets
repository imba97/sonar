import { AutoCacheMode, CacheLimitGb } from '../cache/SongCacheTypes';
import { SongCache } from '../cache/SongCache';
import { SongCacheSettingsStore } from '../cache/SongCacheSettingsStore';
import { SongCacheStore } from '../cache/SongCacheStore';
import { CardContainer } from '../components/layout/CardContainer';
import { UiTokens } from '../ui/tokens/UiTokens';

interface SelectOption {
  value: string;
}

@Component
export struct CacheSettingsPage {
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageLink('songCacheLimitGb') songCacheLimitGb: number = 2;
  @StorageLink('songCacheAutoMode') songCacheAutoMode: string = 'wifi_only';

  private readonly autoCacheOptions: SelectOption[] = [
    { value: '关闭' },
    { value: '开启' },
    { value: '仅在 WiFi 下开启' }
  ];

  private readonly limitOptions: SelectOption[] = [
    { value: '1 GB' },
    { value: '2 GB' },
    { value: '5 GB' },
    { value: '10 GB' }
  ];

  private autoCacheSelectIndex(): number {
    if (this.songCacheAutoMode === 'off') {
      return 0;
    }
    if (this.songCacheAutoMode === 'always') {
      return 1;
    }
    return 2;
  }

  private limitSelectIndex(): number {
    const limitGb: number = this.songCacheLimitGb;
    if (limitGb === 1) {
      return 0;
    }
    if (limitGb === 2) {
      return 1;
    }
    if (limitGb === 5) {
      return 2;
    }
    return 3;
  }

  private async onAutoCacheSelect(index: number): Promise<void> {
    let mode: AutoCacheMode = 'wifi_only';
    if (index === 0) {
      mode = 'off';
    } else if (index === 1) {
      mode = 'always';
    }
    await SongCacheSettingsStore.getInstance().setAutoCacheMode(mode);
  }

  private async onLimitSelect(index: number): Promise<void> {
    const limits: CacheLimitGb[] = [1, 2, 5, 10];
    const nextLimit: CacheLimitGb = limits[index] ?? 2;
    await SongCacheSettingsStore.getInstance().setLimitGb(nextLimit);
    await SongCache.evictIfNeeded();
  }

  build() {
    CardContainer() {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 4 }) {
            Text('边听边下')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text('听歌时自动缓存到本地')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Select(this.autoCacheOptions)
            .selected(this.autoCacheSelectIndex())
            .value(this.autoCacheOptions[this.autoCacheSelectIndex()].value)
            .font({ size: 14 })
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
            .optionFont({ size: 14 })
            .onSelect((index: number) => {
              void this.onAutoCacheSelect(index);
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Column({ space: 4 }) {
            Text('缓存上限')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            Text(`已用 ${SongCacheStore.formatBytes(this.songCacheUsedBytes)} / ${this.songCacheLimitGb} GB`)
              .fontSize(12)
              .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Select(this.limitOptions)
            .selected(this.limitSelectIndex())
            .value(this.limitOptions[this.limitSelectIndex()].value)
            .font({ size: 14 })
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .selectedOptionFont({ size: 14, weight: FontWeight.Medium })
            .optionFont({ size: 14 })
            .onSelect((index: number) => {
              void this.onLimitSelect(index);
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
