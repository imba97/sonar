/*
* Copyright (c) 2024 Huawei Device Co., Ltd.
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
import LazyDataSource from '../util/LazyDataSource';

export class Data {
  private static instance: Data;
  lazyDataSource: LazyDataSource<DataSource> = new LazyDataSource();
  static readonly IMAGES: Resource[] =
    [$r(('app.media.lib_icon_12')), $r(('app.media.lib_icon_7')),
      $r(('app.media.lib_icon_103')), $r(('app.media.lib_icon_12'))];
  static readonly MAIN_TEXT: string[] = ['晴天', '七里香', '夜曲', '青花瓷'];
  static readonly SUB_TEXT: string[] = ['周杰伦', '周杰伦', '周杰伦', '周杰伦'];
  static readonly DESCRIPTION_TEXT: string[] = ['播放于 2小时前', '播放于 5小时前', '播放于 昨天', '播放于 前天'];
  static readonly TAG_TEXTS_LIST: string[][] =
    [['流行', '华语'], ['流行', '经典'], ['说唱', '流行'], ['中国风', '经典']];
  static readonly TAG_TEXT_COLORS_LIST: Color[][] =
    [[Color.Brown, Color.Green, Color.Gray], [Color.Brown, Color.Green, Color.Gray],
      [Color.Brown, Color.Green, Color.Gray], [Color.Brown, Color.Green, Color.Gray],
      [Color.Brown, Color.Green, Color.Gray], [Color.Brown, Color.Green, Color.Gray]];

  constructor() {
  }

  public static getInstance(): Data {
    if (!Data.instance) {
      Data.instance =
        new Data();
    }
    return Data.instance;
  }

  /**
   * Data loaded on current view converts network data into rendering data
   */
  getResources(): Promise<void> {
    /**
     * use your web request here
     */
    return new Promise((resolve: Function) => {
      const modelList: Array<DataSource> = [];
      for (let index = 0; index < Data.IMAGES.length;
        index++) {
        modelList.push(new DataSource(
          Data.IMAGES[index],
          Data.MAIN_TEXT[index],
          Data.SUB_TEXT[index],
          Data.DESCRIPTION_TEXT[index],
          Data.TAG_TEXTS_LIST[index],
          Data.TAG_TEXT_COLORS_LIST[index]));
      }
      this.lazyDataSource.pushArrayData(modelList);
      resolve();
    });
  }
}

export class DataSource {
  private image: Resource;
  private mainText: string;
  private subText: string;
  private descriptionText: string;
  private tagTextList: string[];
  private tagTextColorList: Color[];

  constructor(image: Resource, mainText: string, subText: string,
    descriptionText: string, tagTextList: string[], tagTextColorList: Color[]) {
    this.image = image;
    this.mainText = mainText;
    this.subText = subText;
    this.descriptionText = descriptionText;
    this.tagTextList = tagTextList;
    this.tagTextColorList = tagTextColorList;
  }

  getImage(): Resource {
    return this.image;
  }

  getMainText(): string {
    return this.mainText;
  }

  getSubText(): string {
    return this.subText;
  }

  getDescriptionText(): string {
    return this.descriptionText;
  }

  getTagTextList(): string[] {
    return this.tagTextList;
  }

  getTagTextColorList(): Color[] {
    return this.tagTextColorList;
  }
}