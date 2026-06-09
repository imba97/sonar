import { LoginPage } from './LoginPage';
import { AlbumDetailPage } from './AlbumDetailPage';
import { CacheSettingsPage } from './CacheSettingsPage';
import { ExportConfigPage } from './ExportConfigPage';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';

@Builder
function buildCacheSettingsContent() {
  CacheSettingsPage()
}

@Builder
function buildExportConfigContent() {
  ExportConfigPage()
}

@Component
struct CacheSettingsNavPage {
  build() {
    SecondaryHdsDestination({
      title: '缓存设置',
      content: buildCacheSettingsContent
    })
  }
}

@Component
struct ExportConfigNavPage {
  build() {
    SecondaryHdsDestination({
      title: '导出配置',
      content: buildExportConfigContent
    })
  }
}

@Builder
function buildUnknownPage(name: string) {
  Column() {
    Text(`未找到页面: ${name}`)
      .fontSize(16)
      .fontColor('#1C1C1E')
  }
  .width('100%')
  .height('100%')
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
}

@Builder
export function PageMap(name: string) {
  if (name === 'LoginPage') {
    NavDestination() {
      LoginPage()
    }
    .hideTitleBar(true)
  } else if (name === 'AlbumDetailPage') {
    AlbumDetailPage()
  } else if (name === 'CacheSettingsPage') {
    CacheSettingsNavPage()
  } else if (name === 'ExportConfigPage') {
    ExportConfigNavPage()
  } else {
    NavDestination() {
      buildUnknownPage(name)
    }
    .hideTitleBar(true)
  }
}
