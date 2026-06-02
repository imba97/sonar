import { LoginPage } from './LoginPage';
import { LibraryPage } from './LibraryPage';
import { AlbumDetailPage } from './AlbumDetailPage';

@Builder
export function PageMap(name: string) {
  if (name === 'LoginPage') {
    NavDestination() {
      LoginPage()
    }
    .hideTitleBar(true)
  } else if (name === 'LibraryPage') {
    NavDestination() {
      LibraryPage()
    }
    .hideTitleBar(true)
  } else if (name === 'AlbumDetailPage') {
    NavDestination() {
      AlbumDetailPage()
    }
    .hideTitleBar(true)
  } else {
    NavDestination() {
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
    .hideTitleBar(true)
  }
}
