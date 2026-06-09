import { AuthSession } from '../auth/AuthSession';
import { SongCacheStore } from '../cache/SongCacheStore';
import { DangerButton } from '../components/buttons/DangerButton';
import { OuterScreenPreviewEntry } from '../components/debug/OuterScreenPreviewEntry';
import { CardContainer } from '../components/layout/CardContainer';
import { FloatingPageTitle } from '../components/layout/FloatingPageTitle';
import { SonarPageLayout } from '../components/layout/SonarPageLayout';
import {
  FloatingHeaderType,
  SonarPageLayoutOptions,
  SonarPageRole,
  SonarScrollMode
} from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';

const LOGOUT_DESTINATION_TAB_INDEX: number = 1;

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInUser') loggedInUser: string = '';
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('songCacheUsedBytes') songCacheUsedBytes: number = 0;
  @StorageProp('topRectHeight') topInset: number = 0;

  private layoutOptions(): SonarPageLayoutOptions {
    return {
      role: SonarPageRole.TAB_ROOT,
      headerType: FloatingHeaderType.FLOATING_TITLE,
      barToneTabIndex: 2,
      scrollMode: SonarScrollMode.SCROLL
    };
  }

  private async handleLogout(): Promise<void> {
    await AuthSession.signOut();
    AppStorage.setOrCreate<number>('rootTabIndex', LOGOUT_DESTINATION_TAB_INDEX);
  }

  @LocalBuilder
  buildProfileHeader() {
    FloatingPageTitle({
      title: '我的',
      topInset: this.topInset
    })
  }

  @LocalBuilder
  buildProfileBody() {
    Column({ space: UiTokens.SECTION_GAP }) {
      OuterScreenPreviewEntry()

      CardContainer() {
      Row() {
        Column({ space: 4 }) {
          Text('缓存设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text(`已用 ${SongCacheStore.formatBytes(this.songCacheUsedBytes)}`)
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('›')
          .fontSize(20)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.appPathStack.pushPathByName('CacheSettingsPage', null);
      })
    }

    CardContainer() {
      Row() {
        Column({ space: 4 }) {
          Text('导出配置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
          Text('导出服务器登录信息')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('›')
          .fontSize(20)
          .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.appPathStack.pushPathByName('ExportConfigPage', null);
      })
    }

    CardContainer() {
      Column({ space: 10 }) {
        Text(this.isLoggedIn ? (this.loggedInUser.length > 0 ? this.loggedInUser : '已登录用户') : '未登录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(this.isLoggedIn ? this.loggedInServer : '请先在服务器页完成登录')
          .fontSize(12)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
        if (this.isLoggedIn) {
          DangerButton({
            text: '退出登录',
            onPressed: () => {
              this.handleLogout().catch((err: Error) => {
                console.error(`logout failed: ${err.message}`);
              });
            }
          })
            .margin({ top: 6 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
  }

  build() {
    SonarPageLayout({
      options: this.layoutOptions(),
      headerSlot: this.buildProfileHeader,
      content: this.buildProfileBody
    })
  }
}
