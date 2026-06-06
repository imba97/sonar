import { OuterScreenCoverStack } from '../components/playback/OuterScreenCoverStack';
import { OuterScreenProgressBar } from '../components/playback/OuterScreenProgressBar';
import { UiTokens } from '../ui/tokens/UiTokens';

@Component
export struct OuterScreenPlayerPage {
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State private containerWidth: number = 360;
  @State private containerHeight: number = 360;

  private coverDiscSize(): number {
    const minEdge: number = Math.min(this.containerWidth, this.containerHeight);
    if (minEdge <= 0) {
      return 220;
    }
    return Math.floor(minEdge * UiTokens.OUTER_SCREEN_COVER_SIZE_RATIO);
  }

  build() {
    Column() {
      Blank()
        .layoutWeight(1)

      OuterScreenCoverStack({ discSize: this.coverDiscSize() })

      Blank()
        .height(UiTokens.OUTER_SCREEN_COVER_PROGRESS_GAP)

      OuterScreenProgressBar({ barWidth: this.coverDiscSize() })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.topInset,
      bottom: this.bottomInset
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldValue, newValue) => {
      let widthVp: number = 0;
      let heightVp: number = 0;
      if (typeof newValue.width === 'number') {
        widthVp = newValue.width;
      }
      if (typeof newValue.height === 'number') {
        heightVp = newValue.height;
      }
      if (widthVp > 0 && widthVp !== this.containerWidth) {
        this.containerWidth = widthVp;
      }
      if (heightVp > 0 && heightVp !== this.containerHeight) {
        this.containerHeight = heightVp;
      }
    })
  }
}
