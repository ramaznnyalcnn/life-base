import { Platform } from "react-native";

import type { ApiContext } from "../api/client";
import { fetchCalendarDashboard } from "../api/events";
import { fetchMedicationNotificationSchedule } from "../api/medications";

const CHANNEL_ID = "reminders";
const REMINDER_PREFIX = "lifeos-reminder-";
const MEDICATION_PREFIX = "lifeos-medication-";

type NotificationsModule = typeof import("expo-notifications");

let notificationsPromise: Promise<NotificationsModule> | null = null;
let notificationHandlerReady = false;

async function getNotifications(): Promise<NotificationsModule> {
  if (!notificationsPromise) {
    notificationsPromise = import("expo-notifications")
      .then((Notifications) => {
        if (!notificationHandlerReady) {
          Notifications.setNotificationHandler({
            handleNotification: async () => ({
              shouldPlaySound: true,
              shouldSetBadge: false,
              shouldShowBanner: true,
              shouldShowList: true
            })
          });
          notificationHandlerReady = true;
        }
        return Notifications;
      })
      .catch((error) => {
        notificationsPromise = null;
        throw error;
      });
  }

  return notificationsPromise;
}

async function ensureAndroidChannel(Notifications: NotificationsModule): Promise<void> {
  if (Platform.OS !== "android") {
    return;
  }

  await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
    name: "Hatirlaticilar",
    importance: Notifications.AndroidImportance.HIGH,
    vibrationPattern: [0, 250, 250, 250],
    lightColor: "#7c9cff"
  });
}

export async function ensureNotificationPermission(): Promise<boolean> {
  const Notifications = await getNotifications();
  await ensureAndroidChannel(Notifications);

  const existing = await Notifications.getPermissionsAsync();
  if (existing.granted) {
    return true;
  }

  const requested = await Notifications.requestPermissionsAsync();
  return requested.granted;
}

async function cancelLifeOsReminderNotifications(): Promise<void> {
  const Notifications = await getNotifications();
  const scheduled = await Notifications.getAllScheduledNotificationsAsync();
  await Promise.all(
    scheduled
      .filter(
        (request) =>
          request.identifier.startsWith(REMINDER_PREFIX) || request.identifier.startsWith(MEDICATION_PREFIX)
      )
      .map((request) => Notifications.cancelScheduledNotificationAsync(request.identifier))
  );
}

export async function syncReminderNotifications(context: ApiContext): Promise<number> {
  const granted = await ensureNotificationPermission();
  if (!granted) {
    throw new Error("Bildirim izni verilmedi.");
  }

  const Notifications = await getNotifications();
  const [dashboard, medicationSchedule] = await Promise.all([
    fetchCalendarDashboard(context, false),
    fetchMedicationNotificationSchedule(context)
  ]);
  const now = Date.now();
  await cancelLifeOsReminderNotifications();

  const futureReminders = dashboard.pending_reminders.filter((reminder) => {
    const timestamp = new Date(reminder.remind_at).getTime();
    return Number.isFinite(timestamp) && timestamp > now;
  });
  const futureMedicationDoses = medicationSchedule.filter((dose) => {
    const timestamp = new Date(dose.notify_at).getTime();
    return Number.isFinite(timestamp) && timestamp > now;
  });

  await Promise.all(
    [
      ...futureReminders.map((reminder) =>
        Notifications.scheduleNotificationAsync({
          identifier: `${REMINDER_PREFIX}${reminder.id}`,
          content: {
            title: reminder.event_title || "life-base",
            body: "Yaklasan etkinlik hatirlatmasi.",
            data: {
              eventId: reminder.event_id,
              reminderId: reminder.id,
              kind: "event"
            }
          },
          trigger: {
            type: Notifications.SchedulableTriggerInputTypes.DATE,
            date: new Date(reminder.remind_at),
            channelId: CHANNEL_ID
          }
        })
      ),
      ...futureMedicationDoses.map((dose) =>
        Notifications.scheduleNotificationAsync({
          identifier: `${MEDICATION_PREFIX}${dose.medication_id}-${new Date(dose.scheduled_for).getTime()}`,
          content: {
            title: dose.medication_name || "Ilac zamani",
            body: dose.instructions ? `${dose.dosage} / ${dose.instructions}` : dose.dosage,
            data: {
              medicationId: dose.medication_id,
              scheduledFor: dose.scheduled_for,
              kind: "medication"
            },
          },
          trigger: {
            type: Notifications.SchedulableTriggerInputTypes.DATE,
            date: new Date(dose.notify_at),
            channelId: CHANNEL_ID
          }
        })
      )
    ]
  );

  return futureReminders.length + futureMedicationDoses.length;
}

export async function syncReminderNotificationsIfAllowed(context: ApiContext): Promise<number> {
  const Notifications = await getNotifications();
  await ensureAndroidChannel(Notifications);

  const existing = await Notifications.getPermissionsAsync();
  if (!existing.granted) {
    return 0;
  }

  return syncReminderNotifications(context);
}

export async function scheduleTestNotification(): Promise<void> {
  const granted = await ensureNotificationPermission();
  if (!granted) {
    throw new Error("Bildirim izni verilmedi.");
  }

  const Notifications = await getNotifications();
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "life-base",
      body: "Test bildirimi hazir."
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: 3,
      channelId: CHANNEL_ID
    }
  });
}
