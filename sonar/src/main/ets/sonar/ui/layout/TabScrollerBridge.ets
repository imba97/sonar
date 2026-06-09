/** Tab 根页 Scroller 注册表，供 HdsNavigation.bindToScrollable 绑定当前 Tab */
@Observed
export class TabScrollerBridge {
  private scrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller()];
  activeTabIndex: number = 0;

  scrollerForTab(tabIndex: number): Scroller {
    if (tabIndex >= 0 && tabIndex < this.scrollers.length) {
      return this.scrollers[tabIndex];
    }
    return this.scrollers[0];
  }

  setActiveTab(tabIndex: number): void {
    if (tabIndex >= 0 && tabIndex < this.scrollers.length) {
      this.activeTabIndex = tabIndex;
    }
  }

  activeScroller(): Scroller {
    return this.scrollers[this.activeTabIndex];
  }
}
