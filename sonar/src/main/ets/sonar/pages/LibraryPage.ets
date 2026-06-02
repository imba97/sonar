import { AuthStore } from '../auth/AuthStore';
import { LibraryViewModel } from '../viewmodel/LibraryViewModel';
import { Album, AlbumDetailRouteParam } from '../api/SubsonicTypes';
import { SuccessButton } from '../components/buttons/SuccessButton';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { CardContainer } from '../components/layout/CardContainer';
import { AutoMarqueeText } from '../components/layout/AutoMarqueeText';
import { PageScaffold } from '../components/layout/PageScaffold';
import { UiTokens } from '../ui/tokens/UiTokens';
import deviceInfo from '@ohos.deviceInfo';

@Component
export struct LibraryPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('showMiniPlayer') showMiniPlayer: boolean = false;
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State vm: LibraryViewModel = new LibraryViewModel();
  @State private _isAuthenticated: boolean = false;
  @State private _searchKeyword: string = '';
  @State private _gridColumns: number = 1;

  private supportsHdsTabs(): boolean {
    return deviceInfo.distributionOSApiVersion >= 60100;
  }

  private resolveVpLength(value: Length): number {
    if (typeof value === 'number') {
      // Area.width/height 在 onAreaChange 中语义单位为 vp，number 直接使用即可。
      return value;
    }
    if (typeof value === 'string') {
      if (value.endsWith('vp')) {
        return Number.parseFloat(value);
      }
      if (value.endsWith('px')) {
        return this.getUIContext().px2vp(Number.parseFloat(value));
      }
      const parsed: number = Number.parseFloat(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    // Resource 等非数值长度在此场景无法换算，回退为 0
    return 0;
  }

  private updateGridColumnsByWidth(widthVp: number): void {
    const safeWidthVp: number = Math.max(0, widthVp);
    const columnsByWidth: number = Math.floor(
      (safeWidthVp + UiTokens.LIBRARY_GRID_GAP) /
      (UiTokens.LIBRARY_CARD_MIN_WIDTH + UiTokens.LIBRARY_GRID_GAP)
    );
    const nextColumns: number = Math.max(1, Math.min(3, columnsByWidth));
    if (nextColumns !== this._gridColumns) {
      this._gridColumns = nextColumns;
    }
  }

  private listStartOffset(): number {
    return this.topInset + UiTokens.LIBRARY_SEARCH_TOP_MARGIN + UiTokens.LIBRARY_SEARCH_HEIGHT +
      UiTokens.LIBRARY_SEARCH_CONTENT_GAP;
  }

  private listEndOffset(): number {
    if (this.showMiniPlayer) {
      return UiTokens.MINI_PLAYER_TAB_OFFSET + UiTokens.FLOATING_TAB_BAR_HEIGHT + this.bottomInset +
        UiTokens.LIBRARY_LIST_EDGE_GAP;
    }
    return UiTokens.FLOATING_TAB_BAR_HEIGHT + UiTokens.FLOATING_TAB_BAR_BOTTOM_MARGIN + this.bottomInset +
      UiTokens.LIBRARY_LIST_EDGE_GAP;
  }

  private submitSearch(): void {
    const keyword: string = this._searchKeyword.trim();
    if (keyword.length === 0) {
      if (this.vm.isSearchMode || this.vm.searchQuery.length > 0) {
        void this.vm.loadNewest();
      }
      return;
    }
    if (this.vm.isSearchMode && keyword === this.vm.searchQuery) {
      return;
    }
    void this.vm.searchAlbums(keyword);
  }

  private retryLoad(): void {
    if (this.vm.isSearchMode) {
      void this.vm.searchAlbums(this.vm.searchQuery);
      return;
    }
    void this.vm.loadNewest();
  }

  @Builder
  private buildAlbumCard(album: Album) {
    CardContainer() {
      Column({ space: 10 }) {
        if (album.coverArt !== undefined && album.coverArt.length > 0) {
          Image(this.vm.coverUrl(album.coverArt))
            .width('100%')
            .height(UiTokens.LIBRARY_CARD_COVER_HEIGHT)
            .borderRadius(10)
            .objectFit(ImageFit.Cover)
            .alt('#E5E5EA')
        } else {
          Column() {
            Text('♪')
              .fontSize(30)
              .fontColor(UiTokens.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .height(UiTokens.LIBRARY_CARD_COVER_HEIGHT)
          .borderRadius(10)
          .backgroundColor(UiTokens.COLOR_PLACEHOLDER_BG)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }

        Column({ space: 4 }) {
          AutoMarqueeText({
            text: album.title ?? album.name ?? '未知专辑',
            fontSize: 15,
            fontWeight: FontWeight.Medium,
            fontColor: UiTokens.COLOR_TEXT_PRIMARY
          })
            .width('100%')
            .height(UiTokens.LIBRARY_CARD_TITLE_HEIGHT)

          Text(album.artist.length > 0 ? album.artist : '未知歌手')
            .fontSize(13)
            .fontColor(UiTokens.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  @Builder
  private buildFloatingSearchBox() {
    Row() {
      if (this.supportsHdsTabs()) {
        Row() {
          TextInput({ text: $$this._searchKeyword, placeholder: '搜索媒体库' })
            .width('100%')
            .height(UiTokens.LIBRARY_SEARCH_HEIGHT)
            .borderRadius(UiTokens.LIBRARY_SEARCH_HEIGHT / 2)
            .backgroundColor(Color.Transparent)
            .padding({ left: 18, right: 18 })
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
            .enterKeyType(EnterKeyType.Search)
            .onSubmit((_enterKey: EnterKeyType) => {
              this.submitSearch();
            })
        }
        .width('100%')
        .borderRadius(UiTokens.LIBRARY_SEARCH_HEIGHT / 2)
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
        .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      } else {
        Row() {
          TextInput({ text: $$this._searchKeyword, placeholder: '搜索媒体库' })
            .width('100%')
            .height(UiTokens.LIBRARY_SEARCH_HEIGHT)
            .borderRadius(UiTokens.LIBRARY_SEARCH_HEIGHT / 2)
            .backgroundColor(Color.Transparent)
            .padding({ left: 18, right: 18 })
            .fontColor(UiTokens.COLOR_TEXT_PRIMARY)
            .placeholderColor(UiTokens.COLOR_TEXT_SECONDARY)
            .enterKeyType(EnterKeyType.Search)
            .onSubmit((_enterKey: EnterKeyType) => {
              this.submitSearch();
            })
        }
        .width('100%')
        .borderRadius(UiTokens.LIBRARY_SEARCH_HEIGHT / 2)
        .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .backgroundColor(UiTokens.COLOR_GLASS_BAR_BG)
        .border({ width: 1, color: UiTokens.COLOR_GLASS_BAR_BORDER })
      }
    }
    .width('100%')
    .padding({
      left: UiTokens.LIBRARY_SEARCH_SIDE_PADDING,
      right: UiTokens.LIBRARY_SEARCH_SIDE_PADDING,
      top: this.topInset + UiTokens.LIBRARY_SEARCH_TOP_MARGIN
    })
  }

  @Builder
  private buildAlbumsList() {
    List({ space: UiTokens.LIBRARY_GRID_GAP }) {
      if (this.vm.isLoading && this.vm.albums.length === 0) {
        ListItem() {
          LoadingState({ message: this.vm.isSearchMode ? '正在搜索专辑…' : '正在获取专辑…' })
        }
      } else if (this.vm.errorMessage.length > 0 && this.vm.albums.length === 0) {
        ListItem() {
          Column() {
            ErrorState({
              message: this.vm.errorMessage,
              onRetryPress: () => {
                this.retryLoad();
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
          .padding({ left: 6, right: 6 })
        }
      } else if (this.vm.albums.length === 0) {
        ListItem() {
          EmptyState({
            title: this.vm.isSearchMode ? '未找到结果' : '暂无数据',
            subtitle: this.vm.isSearchMode ? '试试更换关键词后再回车搜索' : '媒体库中还没有专辑'
          })
        }
      } else {
        ForEach(this.vm.albums, (album: Album) => {
          ListItem() {
            this.buildAlbumCard(album)
          }
          .onClick(() => {
            const routeParam: AlbumDetailRouteParam = { albumId: album.id };
            this.appPathStack.pushPathByName('AlbumDetailPage', routeParam);
          })
        }, (album: Album) => album.id)
      }

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
    .height('100%')
    .padding({
      left: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING,
      right: UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING
    })
    .backgroundColor(Color.Transparent)
    .contentStartOffset(this.listStartOffset())
    .contentEndOffset(this.listEndOffset())
    .lanes(this.vm.albums.length > 0 ? this._gridColumns : 1, `${UiTokens.LIBRARY_GRID_GAP}vp`)
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onAreaChange((_oldValue, newValue) => {
      const widthVp: number = this.resolveVpLength(newValue.width) - UiTokens.LIBRARY_PAGE_HORIZONTAL_PADDING * 2;
      this.updateGridColumnsByWidth(widthVp);
    })
    .onReachEnd(() => {
      void this.vm.loadMore();
    })
  }

  async aboutToAppear(): Promise<void> {
    await AuthStore.getInstance().ensureReady();
    if (!AuthStore.getInstance().isLoggedIn()) {
      this.appPathStack.replacePathByName('LoginPage', null);
      return;
    }
    this._isAuthenticated = true;
    this._searchKeyword = this.vm.searchQuery;
    if (this.vm.albums.length === 0) {
      if (this._searchKeyword.length > 0) {
        void this.vm.searchAlbums(this._searchKeyword);
      } else {
        void this.vm.loadNewest();
      }
    }
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
        topPadding: 0,
        bottomPadding: 0,
        applySystemInsets: false
      }) {
        Stack({ alignContent: Alignment.Top }) {
          this.buildAlbumsList()
          this.buildFloatingSearchBox()
        }
        .width('100%')
        .height('100%')
      }
    }
  }
}
