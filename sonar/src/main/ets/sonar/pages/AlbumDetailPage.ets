import { AlbumDetailRouteParam, Song } from '../api/SubsonicTypes';
import { AlbumDetailViewModel } from '../viewmodel/AlbumDetailViewModel';
import { LoadingState } from '../components/feedback/LoadingState';
import { ErrorState } from '../components/feedback/ErrorState';
import { TagButton } from '../components/buttons/TagButton';
import { SecondaryButton } from '../components/buttons/SecondaryButton';
import { CardContainer } from '../components/layout/CardContainer';
import { PageScaffold } from '../components/layout/PageScaffold';
import { DropdownActionItem, DropdownActionMenu } from '../components/overlays/DropdownActionMenu';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ToastUtil } from '../common/ToastUtil';
import { PlaybackController } from '../playback/PlaybackController';
import { PlaybackSnapshot } from '../playback/PlaybackSnapshot';

@Component
export struct AlbumDetailPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: AlbumDetailViewModel = new AlbumDetailViewModel();
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @State private albumId: string = '';
  @State private menuVisible: boolean = false;
  @State private menuSongTitle: string = '';
  @State private menuSong: Song | null = null;
  private readonly menuActions: DropdownActionItem[] = [
    {
      id: 'play-next',
      label: '下一首播放',
      backgroundColor: UiTokens.COLOR_SUCCESS_SOFT_BG,
      fontColor: UiTokens.COLOR_SUCCESS
    },
    {
      id: 'download',
      label: '下载',
      backgroundColor: UiTokens.COLOR_WARNING_SOFT_BG,
      fontColor: UiTokens.COLOR_WARNING
    },
    {
      id: 'detail',
      label: '详情',
      backgroundColor: UiTokens.COLOR_INFO_SOFT_BG,
      fontColor: UiTokens.COLOR_INFO
    }
  ];

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private openMoreMenu(song: Song): void {
    this.menuSong = song;
    this.menuSongTitle = song.title;
    this.menuVisible = true;
  }

  private closeMoreMenu(): void {
    this.menuSong = null;
    this.menuVisible = false;
    this.menuSongTitle = '';
  }

  private onMenuSelect(actionId: string): void {
    if (actionId === 'play-next') {
      if (this.menuSong !== null) {
        void PlaybackController.enqueueNext(this.menuSong);
      }
      this.showToast(`已加入下一首：${this.menuSongTitle}`);
    } else if (actionId === 'download') {
      this.showToast(`开始下载：${this.menuSongTitle}`);
    } else if (actionId === 'detail') {
      this.showToast(`跳转音乐详情：${this.menuSongTitle}`);
    }
    this.closeMoreMenu();
  }

  private playSong(index: number, song: Song): void {
    const albumCover: string = this.vm.album?.coverArt ?? '';
    void PlaybackController.playQueue(this.vm.songs, index, albumCover);
    this.showToast(`开始播放：${song.title}`);
  }

  async aboutToAppear(): Promise<void> {
    const currentIndex: number = this.appPathStack.size() - 1;
    const rawParam: Object | undefined =
      currentIndex >= 0 ? this.appPathStack.getParamByIndex(currentIndex) as Object : undefined;
    const routeParam: AlbumDetailRouteParam | undefined =
      rawParam as AlbumDetailRouteParam | undefined;
    if (routeParam === undefined || routeParam.albumId === undefined || routeParam.albumId.length === 0) {
      this.vm.errorMessage = '缺少专辑参数，无法加载详情';
      return;
    }
    this.albumId = routeParam.albumId;
    await this.vm.load(this.albumId);
  }

  build() {
    Stack() {
      PageScaffold({
        pageBackground: UiTokens.COLOR_PAGE_BG,
        topPadding: 10,
        bottomPadding: this.playback.showMiniPlayer ? UiTokens.MINI_PLAYER_BOTTOM_PADDING : 12
      }) {
        Column() {
          Row() {
            SecondaryButton({
              text: '返回',
              onPressed: () => {
                this.appPathStack.pop();
              }
            })
            Blank()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          if (this.vm.isLoading) {
            LoadingState({ message: '正在加载专辑详情…' })
          } else if (this.vm.errorMessage.length > 0 || this.vm.album === null) {
            ErrorState({
              message: this.vm.errorMessage.length > 0 ? this.vm.errorMessage : '专辑详情加载失败',
              onRetryPress: () => {
                void this.vm.load(this.albumId);
              }
            })
          } else {
            Column() {
              Column() {
                if (this.vm.album.coverArt !== undefined && this.vm.album.coverArt.length > 0) {
                  Image(this.vm.coverUrl(this.vm.album.coverArt))
                    .width(180)
                    .height(180)
                    .borderRadius(18)
                    .objectFit(ImageFit.Cover)
                    .alt('#E5E5EA')
                } else {
                  Column() {
                    Text('♪')
                      .fontSize(56)
                      .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
                  }
                  .width(180)
                  .height(180)
                  .borderRadius(18)
                  .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                }
                Text(this.vm.album.title ?? this.vm.album.name ?? '未知专辑')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                  .margin({ top: 14 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${this.vm.album.artist} · ${this.vm.songs.length} 首`)
                  .fontSize(13)
                  .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                  .margin({ top: 6 })
              }
              .width('100%')
              .padding({ top: 8, bottom: 14 })
              .alignItems(HorizontalAlign.Center)

              List({ space: 8 }) {
                ForEach(this.vm.songs, (song: Song, index: number) => {
                  ListItem() {
                    CardContainer() {
                      Row() {
                        Column() {
                          Text(`${index + 1}. ${song.title}`)
                            .fontSize(14)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(song.artist)
                            .fontSize(12)
                            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
                            .margin({ top: 4 })
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        TagButton({
                          text: '更多',
                          onPressed: () => {
                            this.openMoreMenu(song);
                          }
                        })
                      }
                      .width('100%')
                      .onClick(() => {
                        this.playSong(index, song);
                      })
                    }
                  }
                }, (song: Song) => song.id)
              }
              .width('100%')
              .layoutWeight(1)
              .padding({ left: 16, right: 16, bottom: 16 })
              .listDirection(Axis.Vertical)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
            }
            .width('100%')
            .layoutWeight(1)
          }
        }
        .width('100%')
      }

      if (this.menuVisible) {
        DropdownActionMenu({
          isVisible: this.menuVisible,
          title: this.menuSongTitle,
          actions: this.menuActions,
          closeMenu: () => {
            this.closeMoreMenu();
          },
          selectAction: (id: string) => {
            this.onMenuSelect(id);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
