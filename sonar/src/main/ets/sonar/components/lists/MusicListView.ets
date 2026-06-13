import { Song } from '../../api/SubsonicTypes';
import { SubsonicClient } from '../../api/SubsonicClient';
import { SongCache } from '../../cache/SongCache';
import { TagButtonMenuItem } from '../buttons/TagButton';
import { MoreMenuIconButton } from '../buttons/MoreMenuIconButton';
import { AutoMarqueeText } from '../layout/AutoMarqueeText';
import { ToastUtil } from '../../common/ToastUtil';
import { PlaybackService } from '../../playback/PlaybackService';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';

export type MusicListVariant = 'playlist' | 'album' | 'browse';

@Component
export struct MusicListView {
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @Prop songs: Song[] = [];
  @Prop highlightSongId: string = '';
  @Prop listVariant: MusicListVariant = 'playlist';
  @Prop showArtist: boolean = false;
  @Prop showAlbumCover: boolean = false;
  @Prop albumCoverArtId: string = '';

  private static readonly COVER_SIZE: number = 44;
  private static readonly COVER_RADIUS: number = 8;

  private static readonly ARTIST_FONT_SIZE: number = 11;
  private static readonly META_FONT_SIZE: number = 11;

  private isHighlighted(song: Song): boolean {
    return this.highlightSongId.length > 0 && song.id === this.highlightSongId;
  }

  private isNowPlaying(song: Song): boolean {
    return this.playback.track !== null &&
      this.playback.track.id === song.id &&
      this.playback.isPlaying();
  }

  private formatDurationSeconds(seconds: number): string {
    if (seconds <= 0) {
      return '--:--';
    }
    const totalSeconds: number = Math.floor(seconds);
    const hours: number = Math.floor(totalSeconds / 3600);
    const minutes: number = Math.floor((totalSeconds % 3600) / 60);
    const remainSeconds: number = totalSeconds % 60;
    const paddedMinutes: string = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const paddedSeconds: string = remainSeconds < 10 ? `0${remainSeconds}` : `${remainSeconds}`;
    if (hours > 0) {
      return `${hours}:${paddedMinutes}:${paddedSeconds}`;
    }
    return `${minutes}:${paddedSeconds}`;
  }

  private trailingMetaText(song: Song): string {
    if (this.isNowPlaying(song)) {
      return '正在播放';
    }
    return this.formatDurationSeconds(song.duration);
  }

  private showToast(message: string): void {
    ToastUtil.show(this, message, 1600);
  }

  private buildPlaylistMenuItems(song: Song): TagButtonMenuItem[] {
    return [
      {
        value: '移除',
        action: (): void => {
          const snapshot = PlaybackService.getPlaylistSnapshot();
          let removeIndex: number = -1;
          for (let i: number = 0; i < snapshot.items.length; i++) {
            if (snapshot.items[i].id === song.id) {
              removeIndex = i;
              break;
            }
          }
          if (removeIndex >= 0) {
            void PlaybackService.removeFromPlaylist(removeIndex);
          }
        }
      }
    ];
  }

  private buildAlbumMenuItems(song: Song): TagButtonMenuItem[] {
    return [
      {
        value: '下一首播放',
        action: (): void => {
          void PlaybackService.enqueueNext(song);
          this.showToast(`已加入下一首：${song.title}`);
        }
      },
      {
        value: '添加到播放列表',
        action: (): void => {
          void this.appendSongToPlaylist(song);
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

  private async appendSongToPlaylist(song: Song): Promise<void> {
    const added: number = await PlaybackService.appendToPlaylist([song]);
    if (added > 0) {
      this.showToast(`已添加到播放列表：${song.title}`);
    } else {
      this.showToast(`已在播放列表中：${song.title}`);
    }
  }

  private menuItemsFor(song: Song): TagButtonMenuItem[] {
    if (this.listVariant === 'album' || this.listVariant === 'browse') {
      return this.buildAlbumMenuItems(song);
    }
    return this.buildPlaylistMenuItems(song);
  }

  private hasMoreMenu(): boolean {
    return this.listVariant === 'playlist' || this.listVariant === 'album' ||
      this.listVariant === 'browse';
  }

  private resolveCoverArtId(song: Song): string {
    if (song.coverArt !== undefined && song.coverArt.length > 0) {
      return song.coverArt;
    }
    return this.albumCoverArtId;
  }

  private coverUrlFor(song: Song): string | undefined {
    const coverArt: string = this.resolveCoverArtId(song);
    if (coverArt.length === 0) {
      return undefined;
    }
    return SubsonicClient.getInstance().getCoverArtUrl(coverArt, 120);
  }

  private handleItemClick(index: number, song: Song): void {
    if (this.listVariant === 'playlist') {
      void PlaybackService.playFromPlaylistIndex(index);
      return;
    }
    if (this.listVariant === 'album' || this.listVariant === 'browse') {
      const coverArt: string = this.listVariant === 'browse' ?
        this.resolveCoverArtId(song) : this.albumCoverArtId;
      void PlaybackService.playQueue(this.songs, index, coverArt).then(() => {
        PlaybackService.setPlaybackMode('listLoop');
      });
      this.showToast(`开始播放：${song.title}`);
    }
  }

  @Builder
  private buildDivider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(UiTokens.COLOR_CARD_BORDER)
      .opacity(0.45)
  }

  @Builder
  private buildAlbumCoverThumb(song: Song) {
    if (this.showAlbumCover || this.listVariant === 'browse') {
      if (this.coverUrlFor(song) !== undefined) {
        Image(this.coverUrlFor(song))
          .width(MusicListView.COVER_SIZE)
          .height(MusicListView.COVER_SIZE)
          .borderRadius(MusicListView.COVER_RADIUS)
          .objectFit(ImageFit.Cover)
          .flexShrink(0)
          .margin({ right: 12 })
      } else {
        Column() {
          Text('♪')
            .fontSize(18)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
        }
        .width(MusicListView.COVER_SIZE)
        .height(MusicListView.COVER_SIZE)
        .borderRadius(MusicListView.COVER_RADIUS)
        .backgroundColor(UiTokens.COLOR_CARD_BORDER)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .flexShrink(0)
        .margin({ right: 12 })
      }
    }
  }

  @Builder
  private buildTitleBlock(song: Song) {
    AutoMarqueeText({
      text: song.title,
      fontSize: 14,
      fontWeight: this.isHighlighted(song) ? FontWeight.Bold : FontWeight.Medium,
      fontColor: this.isHighlighted(song) ?
        UiTokens.COLOR_PRIMARY : UiTokens.COLOR_TEXT_PRIMARY,
      secondaryText: this.showArtist ?
        (song.artist.length > 0 ? song.artist : '未知歌手') : '',
      secondaryFontSize: MusicListView.ARTIST_FONT_SIZE,
      secondaryFontColor: UiTokens.COLOR_MUSIC_ARTIST,
      secondaryGapVp: 6
    })
      .layoutWeight(1)
      .height(UiTokens.MUSIC_LIST_TITLE_HEIGHT)
      .flexShrink(1)
      .margin({ right: UiTokens.MUSIC_LIST_TEXT_TRAILING_GAP })
  }

  build() {
    Column() {
      ForEach(this.songs, (song: Song, index: number) => {
        Column() {
          Row() {
            this.buildAlbumCoverThumb(song)
            this.buildTitleBlock(song)

            Text(this.trailingMetaText(song))
              .fontSize(MusicListView.META_FONT_SIZE)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
              .maxLines(1)
              .flexShrink(0)
              .margin({ right: 4 })

            if (this.hasMoreMenu()) {
              MoreMenuIconButton({
                menuItems: this.menuItemsFor(song),
                useDarkOverlay: false
              })
                .flexShrink(0)
            }
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.handleItemClick(index, song);
          })

          if (index < this.songs.length - 1) {
            this.buildDivider()
          }
        }
        .width('100%')
      }, (song: Song) => song.id)
    }
    .width('100%')
  }
}
