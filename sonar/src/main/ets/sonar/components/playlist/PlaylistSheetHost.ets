import { ComponentContent, UIContext } from '@kit.ArkUI';
import { PlaylistSheet } from './PlaylistSheet';
import { PLAYLIST_SHEET_SEQ_KEY } from './PlaylistSheetOpener';

const SHEET_HEIGHT_MEDIUM_VP: number = 480;
const SHEET_HEIGHT_LARGE_VP: number = 720;

@Builder
function buildPlaylistSheetContent() {
  PlaylistSheet()
}

@Component
export struct PlaylistSheetHost {
  @StorageLink(PLAYLIST_SHEET_SEQ_KEY) @Watch('onSheetRequest') private sheetSeq: number = 0;
  private sheetContent: ComponentContent<Object> | null = null;
  private sheetOpen: boolean = false;
  private lastHandledSeq: number = 0;

  aboutToAppear(): void {
    AppStorage.setOrCreate<number>(PLAYLIST_SHEET_SEQ_KEY, 0);
  }

  aboutToDisappear(): void {
    this.closeSheet();
  }

  private onSheetRequest(): void {
    if (this.sheetSeq <= 0 || this.sheetSeq === this.lastHandledSeq) {
      return;
    }
    this.lastHandledSeq = this.sheetSeq;
    this.openSheet();
  }

  private closeSheet(): void {
    if (this.sheetContent !== null) {
      try {
        this.getUIContext().closeBindSheet(this.sheetContent);
      } catch (_err) {
        // sheet may already be closed
      }
      this.sheetContent = null;
      this.sheetOpen = false;
    }
  }

  private openSheet(): void {
    if (this.sheetOpen) {
      return;
    }
    const uiContext: UIContext = this.getUIContext();
    try {
      this.sheetContent = new ComponentContent(uiContext, wrapBuilder(buildPlaylistSheetContent));
      this.sheetOpen = true;
      uiContext.openBindSheet(this.sheetContent, {
        height: SHEET_HEIGHT_MEDIUM_VP,
        detents: [SHEET_HEIGHT_MEDIUM_VP, SHEET_HEIGHT_LARGE_VP],
        backgroundColor: '#F1F3F5',
        onDisappear: (): void => {
          this.sheetContent = null;
          this.sheetOpen = false;
        }
      });
    } catch (_err) {
      this.sheetContent = null;
      this.sheetOpen = false;
    }
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}
