import { PlaybackSnapshot } from '../../playback/PlaybackSnapshot';
import { UiTokens } from '../../ui/tokens/UiTokens';
import { PlaybackCoverDisc } from '../playback/PlaybackCoverDisc';

@Component
export struct MiniBarCoverDisc {
  @Prop outerSize: number = UiTokens.FLOATING_TAB_BAR_HEIGHT;
  @Prop coverInset: number = UiTokens.MINI_BAR_BALL_COVER_INSET;
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();

  private innerSize(): number {
    return Math.max(0, this.outerSize - this.coverInset * 2);
  }

  private coverArtId(): string {
    if (this.playback.track === null) {
      return '';
    }
    return this.playback.track.coverArtId;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      PlaybackCoverDisc({
        discSize: this.innerSize(),
        coverArtId: this.coverArtId(),
        coverRevision: this.playback.coverRevision,
        loading: this.playback.showMiniPlayer && this.playback.isLoading(),
        spinning: this.playback.isPlaying(),
        showCover: this.playback.showMiniPlayer
      })
    }
    .width(this.outerSize)
    .height(this.outerSize)
    .borderRadius(this.outerSize / 2)
    .clip(true)
  }
}
