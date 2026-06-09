/** Scroller 不能作为 @Provide/@Consume 类型，经 Observed 包装后向下传递 */
@Observed
export class SonarPageScrollerHolder {
  scroller: Scroller = new Scroller();
}
