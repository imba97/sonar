import { MusicListView } from '../lists/MusicListView';
import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { PlaylistSnapshot } from '../../playback/PlaylistSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';

@Component
export struct PlaylistSheet {
  @StorageLink('playlist') playlist: PlaylistSnapshot = PlaylistSnapshot.empty();
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();

  build() {
    Column() {
      Row({ space: 8 }) {
        Text('播放列表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
        Text(`${this.playlist.items.length} 首`)
          .fontSize(13)
          .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          .margin({ top: 2 })
      }
      .width('100%')
      .padding({ left: 20, right: 48, top: 16, bottom: 12 })

      if (this.playlist.items.length === 0) {
        Column() {
          Text('播放列表为空')
            .fontSize(14)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
          Text('从专辑菜单添加曲目，或点击歌曲开始播放')
            .fontSize(12)
            .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24 })
      } else {
        Scroll() {
          Column() {
            MusicListView({
              songs: this.playlist.items,
              highlightSongId: this.playback.track !== null ? this.playback.track.id : '',
              listVariant: 'playlist',
              showArtist: true
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(UiTokens.COLOR_PAGE_BG)
  }
}
