/** 管线观测计数（F4） */
export class PipelineMetricsSnapshot {
  trackStarts: number = 0;
  migrates: number = 0;
  seeks: number = 0;
  fetchCompletes: number = 0;
  fetchErrors: number = 0;
  rebufferCount: number = 0;
}

export class PipelineMetrics {
  private static trackStarts: number = 0;
  private static migrates: number = 0;
  private static seeks: number = 0;
  private static fetchCompletes: number = 0;
  private static fetchErrors: number = 0;
  private static rebufferCount: number = 0;

  static recordTrackStart(): void {
    PipelineMetrics.trackStarts++;
  }

  static recordMigrate(): void {
    PipelineMetrics.migrates++;
  }

  static recordSeek(): void {
    PipelineMetrics.seeks++;
  }

  static recordFetchComplete(): void {
    PipelineMetrics.fetchCompletes++;
  }

  static recordFetchError(): void {
    PipelineMetrics.fetchErrors++;
  }

  static recordRebuffer(): void {
    PipelineMetrics.rebufferCount++;
  }

  static snapshot(): PipelineMetricsSnapshot {
    const result: PipelineMetricsSnapshot = new PipelineMetricsSnapshot();
    result.trackStarts = PipelineMetrics.trackStarts;
    result.migrates = PipelineMetrics.migrates;
    result.seeks = PipelineMetrics.seeks;
    result.fetchCompletes = PipelineMetrics.fetchCompletes;
    result.fetchErrors = PipelineMetrics.fetchErrors;
    result.rebufferCount = PipelineMetrics.rebufferCount;
    return result;
  }
}
