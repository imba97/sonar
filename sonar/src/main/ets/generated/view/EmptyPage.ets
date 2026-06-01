@Component
export struct EmptyPage {
  @Prop content: string = 'default text';

  build() {
    Column() {
      Row() {
        Text('empty page for ')
          .fontSize('25vp')
          .fontColor(Color.Gray)
        Text(this.content)
          .fontSize('25vp')
          .fontColor(Color.Gray)
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
  }
}