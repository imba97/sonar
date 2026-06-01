import { common, wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { Logger } from '../common/Logger';

const NOTIFICATION_ID: number = 1001;
const SLOT_TYPE: notificationManager.SlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;
const ABILITY_NAME: string = 'SonarAbility';

export class BackgroundPlaybackService {
  private static context: common.UIAbilityContext | null = null;
  private static started: boolean = false;
  private static slotInitialized: boolean = false;
  private static agent: Object | null = null;

  static setContext(context: common.UIAbilityContext): void {
    BackgroundPlaybackService.context = context;
  }

  static async start(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    if (BackgroundPlaybackService.context === null) {
      Logger.warn('BackgroundPlaybackService', 'start skipped: missing UIAbilityContext');
      return;
    }
    await BackgroundPlaybackService.ensureNotificationSlot();
    await BackgroundPlaybackService.ensureBackgroundTask();
    await BackgroundPlaybackService.publishNotification(songTitle, songArtist, isPlaying);
  }

  static async update(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    if (!BackgroundPlaybackService.started || BackgroundPlaybackService.context === null) {
      return;
    }
    await BackgroundPlaybackService.publishNotification(songTitle, songArtist, isPlaying);
  }

  static async stop(): Promise<void> {
    if (BackgroundPlaybackService.context === null) {
      return;
    }
    if (BackgroundPlaybackService.started) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(BackgroundPlaybackService.context);
      } catch (err) {
        Logger.warn('BackgroundPlaybackService', `stopBackgroundRunning failed: ${(err as Error).message}`);
      }
      BackgroundPlaybackService.started = false;
    }
    try {
      await notificationManager.cancel(NOTIFICATION_ID);
    } catch (err) {
      Logger.warn('BackgroundPlaybackService', `cancel notification failed: ${(err as Error).message}`);
    }
  }

  static async release(): Promise<void> {
    await BackgroundPlaybackService.stop();
    BackgroundPlaybackService.agent = null;
  }

  private static async ensureBackgroundTask(): Promise<void> {
    if (BackgroundPlaybackService.context === null || BackgroundPlaybackService.started) {
      return;
    }
    try {
      const agent = await BackgroundPlaybackService.ensureWantAgent();
      if (agent === null) {
        Logger.warn('BackgroundPlaybackService', 'startBackgroundRunning skipped: wantAgent unavailable');
        return;
      }
      await backgroundTaskManager.startBackgroundRunning(
        BackgroundPlaybackService.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      BackgroundPlaybackService.started = true;
    } catch (err) {
      const message: string = (err as Error).message;
      if (message.indexOf('9800005') >= 0) {
        BackgroundPlaybackService.started = true;
        return;
      }
      Logger.error('BackgroundPlaybackService', `startBackgroundRunning failed: ${message}`);
    }
  }

  private static async ensureNotificationSlot(): Promise<void> {
    if (BackgroundPlaybackService.slotInitialized) {
      return;
    }
    try {
      await notificationManager.addSlot(SLOT_TYPE);
      BackgroundPlaybackService.slotInitialized = true;
    } catch (err) {
      Logger.warn('BackgroundPlaybackService', `addSlot failed: ${(err as Error).message}`);
    }
  }

  private static async ensureWantAgent(): Promise<Object | null> {
    if (BackgroundPlaybackService.agent !== null) {
      return BackgroundPlaybackService.agent;
    }
    if (BackgroundPlaybackService.context === null) {
      Logger.warn('BackgroundPlaybackService', 'ensureWantAgent skipped: missing UIAbilityContext');
      return null;
    }
    const bundleName: string = BackgroundPlaybackService.context.abilityInfo.bundleName;
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName,
        abilityName: ABILITY_NAME
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      BackgroundPlaybackService.agent = await wantAgent.getWantAgent(info);
    } catch (err) {
      Logger.warn('BackgroundPlaybackService', `getWantAgent failed: ${(err as Error).message}`);
      return null;
    }
    return BackgroundPlaybackService.agent;
  }

  private static async publishNotification(songTitle: string, songArtist: string, isPlaying: boolean): Promise<void> {
    const title: string = songTitle.length > 0 ? songTitle : 'Sonar';
    const text: string = songArtist.length > 0 ? songArtist : 'Audio';
    const hint: string = isPlaying ? 'Playing' : 'Paused';
    const request: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text,
          additionalText: hint
        }
      },
      deliveryTime: Date.now(),
      showDeliveryTime: true,
      tapDismissed: false
    };
    try {
      await notificationManager.publish(request);
    } catch (err) {
      Logger.warn('BackgroundPlaybackService', `publish notification failed: ${(err as Error).message}`);
    }
  }
}
