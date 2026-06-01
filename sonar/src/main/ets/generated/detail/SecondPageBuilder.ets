/*
* Copyright (c) 2023 Huawei Device Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
import { LoginPage } from '../../sonar/pages/LoginPage';
import { LibraryPage } from '../../sonar/pages/LibraryPage';
import { AlbumDetailPage } from '../../sonar/pages/AlbumDetailPage';
import { SecondPageSearch } from '../detail/SecondPageSearch';

// import reference line
@Builder
export function PageMap(name: string) {
  if (name === 'SearchPage') {
    NavDestination() {
      SecondPageSearch()
    }
    .hideTitleBar(true)
  } else if (name === 'LoginPage') {
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
  }
  // code reference line
  else {
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