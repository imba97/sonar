import { AlbumDetailRouteParam, Song } from '../api/SubsonicTypes';
import { SongCache } from '../cache/SongCache';
import { AlbumDetailViewModel } from '../viewmodel/AlbumDetailViewModel';
import { LoadingState } from '../components/feedback/LoadingState';
import { ErrorState } from '../components/feedback/ErrorState';
import { TagButton, TagButtonMenuItem } from '../components/buttons/TagButton';
import { CardContainer } from '../components/layout/CardContainer';
import { SecondaryHdsDestination } from '../components/navigation/SecondaryHdsDestination';
import { UiTokens } from '../ui/tokens/UiTokens';
import { ToastUtil } from '../common/ToastUtil';
import { PlaybackService } from '../playback/PlaybackService';
import { PlaybackSnapshot } from '../playback/PlaybackSnapshot';

@Component
export struct AlbumDetailPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State vm: AlbumDetailViewModel = new AlbumDetailViewModel();
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @State private albumId: string = '';

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private buildSongMenuItems(song: Song): TagButtonMenuItem[] {
    return [
      {
        value: '下一首播放',
        action: (): void => {
          void PlaybackService.enqueueNext(song);
          this.showToast(`已加入下一首：${song.title}`);
        }
      },
      {
        value: '下载',
        action: (): void => {
          if (SongCache.isComplete(song.id)) {
            this.showToast(`已在缓存中：${song.title}`);
          } else {
            void SongCache.enqueueDownload(song.id);
            this.showToast(`已加入下载：${song.title}`);
          }
        }
      },
      {
        value: '详情',
        action: (): void => {
          this.showToast(`跳转音乐详情：${song.title}`);
        }
      }
    ];
  }

  private playSong(index: number, song: Song): void {
    const albumCover: string = this.vm.album?.coverArt ?? '';
    void PlaybackService.playQueue(this.vm.songs, index, albumCover);
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

  @LocalBuilder
  buildAlbumHeader() {
    Column() {
      if (this.vm.album !== null && this.vm.album.coverArt !== undefined && this.vm.album.coverArt.length > 0) {
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
      if (this.vm.album !== null) {
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
    }
    .width('100%')
    .padding({ top: 8, bottom: 14 })
    .alignItems(HorizontalAlign.Center)
  }

  @LocalBuilder
  buildSongList() {
    Column({ space: 8 }) {
      ForEach(this.vm.songs, (song: Song, index: number) => {
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
              menuItems: this.buildSongMenuItems(song)
            })
          }
          .width('100%')
          .onClick(() => {
            this.playSong(index, song);
          })
        }
      }, (song: Song) => song.id)
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @LocalBuilder
  buildPageContent() {
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
      this.buildAlbumHeader()
      this.buildSongList()
    }
  }

  @LocalBuilder
  buildDestinationContent() {
    this.buildPageContent()
  }

  build() {
    SecondaryHdsDestination({
      title: '专辑',
      contentVariant: 'hero',
      content: this.buildDestinationContent
    })
  }
}
