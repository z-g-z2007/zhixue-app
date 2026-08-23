package com.example.zhixue.backend;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.Map;

/**
 * 提醒调度器：根据当前用户的任务列表 + 提醒设置，调度 AlarmManager 定时触发 ReminderReceiver 弹出横幅通知。
 *
 * 调度规则（有多个执行点，取并集）：
 * 1) 开启统一提醒后，每天在用户设定的全局时间（如 08:00）触发一次"学习时间到啦"
 * 2) 每个"今日应执行的任务"的 start_time 触发一次"任务 X 要开始啦"
 *
 * requestCode 分配（避免 PendingIntent 互相覆盖）：
 *  - 统一提醒 = 1
 *  - 任务提醒 = task.id 的 hashCode + 10000（取绝对值保证非负）
 *
 * 调度对象都以"明天 / 今天之后最近的下一次"为准；Receiver 收到后再重排次日。
 */
public class ReminderScheduler {

    public static final String CHANNEL_ID = "zhixue_study_reminder";
    private static final String TAG = "ReminderScheduler";
    private static final int REQ_GLOBAL = 1;

    public static void ensureChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) ctx.getApplicationContext()
                    .getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm == null) return;
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return;
            NotificationChannel ch = new NotificationChannel(
                    CHANNEL_ID,
                    "学习提醒",
                    NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("每日学习时间到点提醒，任务开始提醒");
            ch.enableLights(true);
            ch.enableVibration(true);
            ch.setShowBadge(true);
            nm.createNotificationChannel(ch);
        }
    }

    /**
     * 根据用户设置重新调度所有提醒（创建任务、保存设置、登录、启动、领取奖励后等都会调用）。
     * @param settings DataStore.getReminderSettings() 的结果
     * @param owner 账号
     * @param allTasks 所有任务
     */
    public static void rescheduleAll(Context ctx, JSONObject settings, String owner, JSONArray allTasks) {
        ensureChannel(ctx);

        AlarmManager am = (AlarmManager) ctx.getApplicationContext()
                .getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;

        // 1. 先取消之前本账号的全部 PendingIntent
        cancelAll(ctx, owner, allTasks);

        if (settings == null) return;
        boolean remindEnabled = settings.optBoolean("remindEnabled", false);
        boolean bannerEnabled = settings.optBoolean("bannerRemind", false);
        if (!remindEnabled || !bannerEnabled) return; // 关了就不排

        // 2. 统一提醒
        String remindTime = settings.optString("remindTime", "08:00");
        String[] hm = remindTime.split(":");
        if (hm.length == 2) {
            try {
                int h = Integer.parseInt(hm[0]);
                int m = Integer.parseInt(hm[1]);
                Calendar fire = nextOccurrence(h, m);
                scheduleOne(ctx, am, REQ_GLOBAL, owner, "GLOBAL", "学习时间到啦", "记得开启今日学习任务，坚持打卡！", fire);
            } catch (Exception ignore) {}
        }

        // 3. 每个今日/明日的任务 start_time 提醒
        String today = DateUtils.today();
        String tomorrow = DateUtils.plusOneDay(today);
        Calendar now = Calendar.getInstance();

        try {
            for (int i = 0; i < allTasks.length(); i++) {
                JSONObject t = allTasks.getJSONObject(i);
                if (!owner.equals(t.getString("owner"))) continue;
                String sd = t.getString("start_date");
                String ed = t.getString("end_date");
                // 简化：若今天在 [sd,ed] 内，检查今天星期匹配；不匹配则看明天。取最近一次匹配日。
                JSONArray wd = t.getJSONArray("week_days");
                java.util.List<Integer> weekDays = new java.util.ArrayList<>();
                for (int j = 0; j < wd.length(); j++) weekDays.add(wd.getInt(j));

                String startDateToTry = null;
                if (DateUtils.isScheduledOn(today, sd, ed, weekDays)) {
                    startDateToTry = today;
                } else if (DateUtils.isScheduledOn(tomorrow, sd, ed, weekDays)) {
                    startDateToTry = tomorrow;
                } else {
                    // 向后找7天内最近一个（防卡死最多看14天）
                    String cursor = tomorrow;
                    for (int k = 0; k < 14; k++) {
                        cursor = DateUtils.plusOneDay(cursor);
                        if (DateUtils.isScheduledOn(cursor, sd, ed, weekDays)
                                && cursor.compareTo(sd) >= 0 && cursor.compareTo(ed) <= 0) {
                            startDateToTry = cursor;
                            break;
                        }
                    }
                }
                if (startDateToTry == null) continue;

                String startTime = t.getString("start_time");
                String[] thm = startTime.split(":");
                if (thm.length != 2) continue;
                int hh, mm;
                try {
                    hh = Integer.parseInt(thm[0]);
                    mm = Integer.parseInt(thm[1]);
                } catch (Exception e) { continue; }

                Calendar cal = DateUtils.parseYMD(startDateToTry);
                cal.set(Calendar.HOUR_OF_DAY, hh);
                cal.set(Calendar.MINUTE, mm);
                cal.set(Calendar.SECOND, 0);
                cal.set(Calendar.MILLISECOND, 0);
                // 如果 startDateToTry 是今天但时间已过，自动切到下一个匹配日（7天内）
                if (cal.getTimeInMillis() <= now.getTimeInMillis()) {
                    cal.add(Calendar.DAY_OF_MONTH, 1);
                    int guards = 0;
                    while (!DateUtils.isScheduledOn(DateUtils.fmt(cal), sd, ed, weekDays) && guards < 14) {
                        cal.add(Calendar.DAY_OF_MONTH, 1);
                        guards++;
                    }
                    if (guards == 14) continue;
                }

                String taskName = t.getString("name");
                int req = (t.getString("id").hashCode() & 0x7fffffff) + 10000;
                scheduleOne(ctx, am, req, owner, t.getString("id"),
                        "「" + taskName + "」要开始啦",
                        "到你计划的" + startTime + "了，开始学习打卡吧！",
                        cal);
            }
        } catch (Exception e) {
            Log.e(TAG, "reschedule task reminders failed", e);
        }
    }

    /**
     * 取消所有已排的提醒（在重排前调用）。
     */
    public static void cancelAll(Context ctx, String owner, JSONArray allTasks) {
        AlarmManager am = (AlarmManager) ctx.getApplicationContext()
                .getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        PendingIntent pi = makePendingIntent(ctx, REQ_GLOBAL, owner, "GLOBAL", "", "",
                PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
        if (pi != null) { am.cancel(pi); pi.cancel(); }

        if (allTasks != null) {
            try {
                for (int i = 0; i < allTasks.length(); i++) {
                    JSONObject t = allTasks.getJSONObject(i);
                    int req = (t.getString("id").hashCode() & 0x7fffffff) + 10000;
                    PendingIntent p = makePendingIntent(ctx, req, owner, t.getString("id"), "", "",
                            PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE);
                    if (p != null) { am.cancel(p); p.cancel(); }
                }
            } catch (Exception ignore) {}
        }
    }

    private static void scheduleOne(Context ctx, AlarmManager am, int req, String owner, String taskId,
                                    String title, String body, Calendar fireAt) {
        Intent intent = new Intent(ctx, ReminderReceiver.class);
        intent.setAction("com.example.zhixue.REMINDER_FIRE");
        intent.putExtra("owner", owner);
        intent.putExtra("taskId", taskId);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        intent.putExtra("req", req);
        PendingIntent pi;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pi = PendingIntent.getBroadcast(ctx, req, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        } else {
            pi = PendingIntent.getBroadcast(ctx, req, intent, PendingIntent.FLAG_UPDATE_CURRENT);
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt.getTimeInMillis(), pi);
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, fireAt.getTimeInMillis(), pi);
            }
        } catch (SecurityException se) {
            // 可能没有 SCHEDULE_EXACT_ALARM 权限（Android 12+），回退到 inexact
            try {
                am.set(AlarmManager.RTC_WAKEUP, fireAt.getTimeInMillis(), pi);
            } catch (Exception ignore) {}
        } catch (Exception e) {
            Log.w(TAG, "scheduleOne failed", e);
        }
    }

    private static PendingIntent makePendingIntent(Context ctx, int req, String owner, String taskId,
                                                   String title, String body, int flags) {
        Intent intent = new Intent(ctx, ReminderReceiver.class);
        intent.setAction("com.example.zhixue.REMINDER_FIRE");
        intent.putExtra("owner", owner);
        intent.putExtra("taskId", taskId);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        intent.putExtra("req", req);
        try {
            return PendingIntent.getBroadcast(ctx, req, intent, flags);
        } catch (Exception e) {
            return null;
        }
    }

    /** 获取"下一次"在给定时分的 Calendar：今天该时间若已过则用明天 */
    public static Calendar nextOccurrence(int hour24, int minute) {
        Calendar now = Calendar.getInstance();
        Calendar target = (Calendar) now.clone();
        target.set(Calendar.HOUR_OF_DAY, hour24);
        target.set(Calendar.MINUTE, minute);
        target.set(Calendar.SECOND, 0);
        target.set(Calendar.MILLISECOND, 0);
        if (!target.after(now)) {
            target.add(Calendar.DAY_OF_MONTH, 1);
        }
        return target;
    }

    /** 用于 Receiver 的发送通知工具（暴露成 public 供 Receiver 复用） */
    public static void fireNotification(Context ctx, String owner, String title, String body, int notifyId) {
        ensureChannel(ctx);
        // 点击通知打开 MainActivity
        Intent launchIntent = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        PendingIntent pi = null;
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pi = PendingIntent.getActivity(ctx, notifyId + 50000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            } else {
                pi = PendingIntent.getActivity(ctx, notifyId + 50000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT);
            }
        }
        NotificationCompat.Builder builder = new NotificationCompat.Builder(ctx, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setDefaults(NotificationCompat.DEFAULT_SOUND | NotificationCompat.DEFAULT_VIBRATE)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);
        if (pi != null) builder.setContentIntent(pi);

        NotificationManager nm = (NotificationManager) ctx.getApplicationContext()
                .getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.notify(notifyId, builder.build());
    }
}
