import { MusicListKind } from '../api/SubsonicTypes';
import { SuccessButton } from '../components/buttons/SuccessButton';
import { GlassSearchBar } from '../components/forms/GlassSearchBar';
import {
  MUSIC_KIND_INDEX_RANDOM,
  MusicKindSegment,
  musicKindFromIndex,
  musicKindToIndex
} from '../components/forms/MusicKindSegment';
import { LoadingState } from '../components/feedback/LoadingState';
import { EmptyState } from '../components/feedback/EmptyState';
import { ErrorState } from '../components/feedback/ErrorState';
import { MusicListView } from '../components/lists/MusicListView';
import { ImmersivePageOffsets } from '../ui/layout/ImmersivePageOffsets';
import { TabScrollerBridge } from '../ui/layout/TabScrollerBridge';
import { SonarPageRole } from '../ui/layout/SonarPageLayoutOptions';
import { UiTokens } from '../ui/tokens/UiTokens';
import { MusicViewModel } from '../viewmodel/MusicViewModel';
import { PlaybackSnapshot } from '../playback/PlaybackSnapshot';

@Component
export struct MusicPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Consume('tabScrollerBridge') tabScrollerBridge: TabScrollerBridge = new TabScrollerBridge();
  @StorageLink('authPhase') @Watch('onAuthSnapshotChanged') authPhase: string = 'booting';
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('rootTabActive') rootTabActive: boolean = false;
  @StorageLink('playback') playback: PlaybackSnapshot = PlaybackSnapshot.idle();
  @StorageProp('topRectHeight') topInset: number = 0;
  @StorageProp('bottomRectHeight') bottomInset: number = 0;
  @State vm: MusicViewModel = new MusicViewModel();
  @State private _searchKeyword: string = '';
  @State private refreshSpinDeg: number = 0;
  @State private randomRefreshing: boolean = false;

  aboutToAppear(): void {
    this.onAuthSnapshotChanged();
  }

  private onAuthSnapshotChanged(): void {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      void this.activateMusic();
    } else if (this.authPhase === 'anonymous') {
      this.vm.reset();
    }
  }

  private async activateMusic(): Promise<void> {
    await this.vm.restoreKindFromStore();
    this._searchKeyword = this.vm.searchQuery;
    if (this.vm.songs.length === 0) {
      if (this._searchKeyword.length > 0) {
        await this.vm.searchSongs(this._searchKeyword);
      } else {
        await this.vm.loadCurrentKind();
      }
    }
  }

  private submitSearch(): void {
    const keyword: string = this._searchKeyword.trim();
    if (keyword.length === 0) {
      if (this.vm.isSearchMode || this.vm.searchQuery.length > 0) {
        void this.vm.loadCurrentKind();
      }
      return;
    }
    if (this.vm.isSearchMode && keyword === this.vm.searchQuery) {
      return;
    }
    void this.vm.searchSongs(keyword);
  }

  private retryLoad(): void {
    if (this.vm.isSearchMode) {
      void this.vm.searchSongs(this.vm.searchQuery);
      return;
    }
    void this.vm.loadCurrentKind();
  }

  private triggerRefreshSpin(): void {
    this.getUIContext()?.animateTo(
      { duration: 400, curve: Curve.EaseOut },
      () => {
        this.refreshSpinDeg = this.refreshSpinDeg + 360;
      }
    );
  }

  private async handleKindSelect(index: number): Promise<void> {
    const nextKind: MusicListKind = musicKindFromIndex(index);
    if (this.vm.isSearchMode && index === MUSIC_KIND_INDEX_RANDOM) {
      this._searchKeyword = '';
      this.vm.clearSearchMode();
      await this.vm.setKind('random');
      return;
    }
    if (this.vm.isSearchMode) {
      await this.vm.setKind(nextKind);
      return;
    }
    if (index === MUSIC_KIND_INDEX_RANDOM &&
      musicKindToIndex(this.vm.kind) === MUSIC_KIND_INDEX_RANDOM) {
      if (this.randomRefreshing || this.vm.isLoading) {
        return;
      }
      this.randomRefreshing = true;
      this.triggerRefreshSpin();
      await this.vm.reloadRandom();
      this.randomRefreshing = false;
      return;
    }
    await this.vm.setKind(nextKind);
  }

  @Builder
  private buildMusicListHeader() {
    Column({ space: UiTokens.SECTION_GAP }) {
      if (!this.vm.isSearchMode) {
        MusicKindSegment({
          selectedIndex: musicKindToIndex(this.vm.kind),
          refreshSpinDeg: this.refreshSpinDeg,
          onSelect: (index: number) => {
            void this.handleKindSelect(index);
          }
        })
      }

      GlassSearchBar({
        keyword: this._searchKeyword,
        onKeywordChange: (value: string) => {
          this._searchKeyword = value;
        },
        placeholder: '搜索歌曲',
        sidePadding: 0,
        onSubmit: () => {
          this.submitSearch();
        }
      })
    }
    .width('100%')
    .padding({
      top: ImmersivePageOffsets.contentTopPadding(SonarPageRole.TAB_ROOT, this.topInset),
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING
    })
    .margin({ bottom: UiTokens.SECTION_GAP })
  }

  @Builder
  private buildSongsList() {
    List({ scroller: this.tabScrollerBridge.scrollerForTab(0) }) {
      ListItemGroup({ header: this.buildMusicListHeader }) {
        if (this.vm.isLoading && this.vm.songs.length === 0) {
          ListItem() {
            LoadingState({ message: this.vm.isSearchMode ? '正在搜索歌曲…' : '正在加载歌曲…' })
          }
        } else if (this.vm.errorMessage.length > 0 && this.vm.songs.length === 0) {
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
        } else if (this.vm.songs.length === 0) {
          ListItem() {
            EmptyState({
              title: this.vm.isSearchMode ? '未找到结果' : '暂无歌曲',
              subtitle: this.vm.isSearchMode ? '试试更换关键词后再回车搜索' :
                (this.isLoggedIn ? '还没有可展示的曲目' : '请在我的 > 服务器完成登录')
            })
          }
        } else {
          ListItem() {
            MusicListView({
              songs: this.vm.songs,
              highlightSongId: this.playback.track !== null ? this.playback.track.id : '',
              listVariant: 'browse',
              showArtist: true,
              showAlbumCover: true
            })
          }
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
    }
    .width('100%')
    .height('100%')
    .padding({
      left: UiTokens.PAGE_HORIZONTAL_PADDING,
      right: UiTokens.PAGE_HORIZONTAL_PADDING
    })
    .backgroundColor(Color.Transparent)
    .contentEndOffset(ImmersivePageOffsets.tabContentEnd(this.bottomInset, this.rootTabActive))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onReachEnd(() => {
      void this.vm.loadMore();
    })
  }

  @Builder
  private buildBootingBody() {
    Column() {
      LoadingState({ message: '正在恢复会话…' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildAnonymousBody() {
    Column() {
      EmptyState({
        title: '未登录',
        subtitle: '请在我的 > 服务器完成登录'
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: UiTokens.PAGE_HORIZONTAL_PADDING, right: UiTokens.PAGE_HORIZONTAL_PADDING })
  }

  build() {
    if (this.authPhase === 'authenticated' && this.isLoggedIn) {
      Column() {
        this.buildSongsList()
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 160,
        colors: [[UiTokens.COLOR_BG_GRADIENT_TOP, 0], [UiTokens.COLOR_BG_GRADIENT_BOTTOM, 1]]
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .id('bar-tone-probe-0')
    } else if (this.authPhase === 'booting') {
      this.buildBootingBody()
    } else {
      this.buildAnonymousBody()
    }
  }
}
