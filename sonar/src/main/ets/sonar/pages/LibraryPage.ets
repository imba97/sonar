import { AuthStore } from '../auth/AuthStore';
import { AuthSession } from '../auth/AuthSession';
import { LibraryViewModel } from '../viewmodel/LibraryViewModel';
import { Album, AlbumDetailRouteParam } from '../api/SubsonicTypes';
import { DangerButton } from '../components/buttons/DangerButton';
import { SuccessButton } from '../components/buttons/SuccessButton';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ToastUtil } from '../common/ToastUtil';

@Component
export struct LibraryPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('loggedInServer') loggedInServer: string = '';
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @State vm: LibraryViewModel = new LibraryViewModel();
  @State private _isAuthenticated: boolean = false;
  @State private _userLabel: string = '';
  @State private _showReloginHint: boolean = false;

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private async handleLogout(): Promise<void> {
    await AuthSession.logout();
    this._isAuthenticated = false;
    this.appPathStack.replacePathByName('LoginPage', null);
  }

  async aboutToAppear(): Promise<void> {
    await AuthStore.getInstance().ensureReady();
    if (!AuthStore.getInstance().isLoggedIn()) {
      this.appPathStack.replacePathByName('LoginPage', null);
      return;
    }
    this._isAuthenticated = true;
    this._userLabel = AppStorage.get<string>('loggedInUser') ?? '';
    this._showReloginHint = !(await AuthStore.getInstance().isLocalUrlPersistedInSession());
    if (this._showReloginHint) {
      this.showToast('检测到本地 URL 未写入当前会话，请重新登录一次');
    }
    this.vm.loadNewest();
  }

  build() {
    if (!this._isAuthenticated || !this.isLoggedIn) {
      PageScaffold({
        pageBackground: UiTokens.COLOR_PAGE_BG
      }) {
        Column() {
        }
      }
    } else {
      PageScaffold({
        pageBackground: UiTokens.COLOR_PAGE_BG,
        topPadding: 10,
        bottomPadding: this.showMiniPlayer ? UiTokens.MINI_PLAYER_WITH_TAB_BOTTOM_PADDING :
          UiTokens.BOTTOM_PADDING_WITH_TAB_BAR
      }) {
        Column() {
          // 顶部栏
          Row() {
            Column() {
              Text('媒体库')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
              if (this._userLabel.length > 0) {
                Text(`${this._userLabel} · ${this.loggedInServer.replace(/^https?:\/\//, '')}`)
                  .fontSize(12)
                  .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                  .margin({ top: 2 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            DangerButton({
              text: '退出',
              onPressed: () => {
                void this.handleLogout();
              }
            })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 12 })

          if (this._showReloginHint) {
            Text('提示：已保存本地 URL，但当前会话未写入。请重新登录后再进行本地切换。')
              .width('100%')
              .fontSize(12)
              .fontColor(UiTokens.COLOR_WARNING)
              .backgroundColor(UiTokens.COLOR_WARNING_SOFT_BG)
              .borderRadius(10)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .margin({ left: 20, right: 20, bottom: 10 })
          }

          if (this.vm.isLoading) {
            LoadingState({ message: '正在获取专辑…' })
          } else if (this.vm.errorMessage.length > 0) {
            Column() {
              ErrorState({
                message: this.vm.errorMessage,
                onRetryPress: () => {
                  void this.vm.loadNewest();
                }
              })
              if (this.vm.authExpired) {
                SuccessButton({
                  text: '重新登录',
                  onPressed: () => {
                    this.appPathStack.replacePathByName('LoginPage', null);
                  }
                })
                .margin({ top: 10 })
              }
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else if (this.vm.albums.length === 0) {
            EmptyState({ title: '暂无数据', subtitle: '媒体库中还没有专辑' })
          } else {
            List({ space: 10 }) {
              ForEach(this.vm.albums, (album: Album) => {
                ListItem() {
                  CardContainer() {
                    Row() {
                      if (album.coverArt !== undefined && album.coverArt.length > 0) {
                        Image(this.vm.coverUrl(album.coverArt))
                          .width(64)
                          .height(64)
                          .borderRadius(10)
                          .objectFit(ImageFit.Cover)
                          .alt('#E5E5EA')
                      } else {
                        Column() {
                          Text('♪')
                            .fontSize(28)
                            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
                        }
                        .width(64)
                        .height(64)
                        .borderRadius(10)
                        .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
                        .justifyContent(FlexAlign.Center)
                        .alignItems(HorizontalAlign.Center)
                      }

                      Column() {
                        Text(album.title ?? album.name ?? '未知专辑')
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(album.artist)
                          .fontSize(13)
                          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .margin({ top: 4 })
                        if (album.songCount !== undefined && album.songCount > 0) {
                          Text(`${album.songCount} 首${album.year !== undefined ? ' · ' + album.year : ''}`)
                            .fontSize(12)
                            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
                            .margin({ top: 4 })
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .margin({ left: 12 })
                      .layoutWeight(1)
                      .height(64)
                      .justifyContent(FlexAlign.Center)
                    }
                    .width('100%')
                  }
                }
                .onClick(() => {
                  const routeParam: AlbumDetailRouteParam = { albumId: album.id };
                  this.appPathStack.pushPathByName('AlbumDetailPage', routeParam);
                })
              }, (album: Album) => album.id)

              if (this.vm.isLoadingMore) {
                ListItem() {
                  Row() {
                    LoadingProgress()
                      .width(22)
                      .height(22)
                      .color(UiTokens.COLOR_TEXT_SECONDARY)
                    Text('加载中…')
                      .fontSize(13)
                      .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .padding({ top: 8, bottom: 8 })
                }
              }
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16, top: 4, bottom: 16 })
            .listDirection(Axis.Vertical)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              void this.vm.loadMore();
            })
          }
        }
        .width('100%')
      }
    }
  }
}
