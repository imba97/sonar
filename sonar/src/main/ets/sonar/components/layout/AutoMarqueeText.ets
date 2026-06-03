@Component
export struct AutoMarqueeText {
  @Prop text: string = '';
  @Prop fontSize: number = 15;
  @Prop fontColor: ResourceColor = Color.Black;
  @Prop fontWeight: FontWeight = FontWeight.Regular;
  @Prop edgeFadeRatio: number = 0.08;
  @State private _contentWidthVp: number = 0;
  @State private _enableEdgeFade: boolean = false;

  private normalizedFadeRatio(): number {
    return Math.max(0.02, Math.min(0.2, this.edgeFadeRatio));
  }

  private resolveVpLength(value: Length): number {
    if (typeof value === 'number') {
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
    return 0;
  }

  private updateEdgeFade(): void {
    const widthVp: number = Math.max(0, this._contentWidthVp);
    if (widthVp <= 0 || this.text.length === 0) {
      this._enableEdgeFade = false;
      return;
    }
    try {
      const textWidthPx: number = this.getUIContext().getMeasureUtils().measureText({
        textContent: this.text,
        fontSize: `${this.fontSize}vp`,
        fontWeight: this.fontWeight
      });
      const containerWidthPx: number = this.getUIContext().vp2px(widthVp);
      const enableThresholdPx: number = 3;
      const disableThresholdPx: number = 1;
      if (this._enableEdgeFade) {
        this._enableEdgeFade = textWidthPx > containerWidthPx + disableThresholdPx;
      } else {
        this._enableEdgeFade = textWidthPx > containerWidthPx + enableThresholdPx;
      }
    } catch (_e) {
      this._enableEdgeFade = false;
    }
  }

  aboutToAppear(): void {
    this.updateEdgeFade();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Text(this.text)
        .fontSize(this.fontSize)
        .fontWeight(this.fontWeight)
        .fontColor(this.fontColor)
        .width('100%')
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .textAlign(TextAlign.Start)
        .clip(true)

      if (this._enableEdgeFade) {
        Row()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 90,
            colors: [
              ['#00FFFFFF', 0],
              ['#FFFFFFFF', this.normalizedFadeRatio()],
              ['#FFFFFFFF', 1 - this.normalizedFadeRatio()],
              ['#00FFFFFF', 1]
            ]
          })
          .blendMode(BlendMode.DST_IN)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .renderGroup(true)
    .onAreaChange((_oldValue, newValue) => {
      const nextWidthVp: number = this.resolveVpLength(newValue.width);
      if (Math.abs(nextWidthVp - this._contentWidthVp) > 0.5) {
        this._contentWidthVp = nextWidthVp;
        this.updateEdgeFade();
      }
    })
  }
}
