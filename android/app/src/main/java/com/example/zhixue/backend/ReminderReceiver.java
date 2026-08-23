package com.example.zhixue.backend;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * AlarmManager 到点触发：弹出横幅通知。
 */
public class ReminderReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        String title = intent.getStringExtra("title");
        String body = intent.getStringExtra("body");
        int req = intent.getIntExtra("req", 0);
        if (title == null) title = "学习时间到啦";
        if (body == null) body = "记得开启今日学习任务！";
        ReminderScheduler.fireNotification(context, intent.getStringExtra("owner"), title, body, req);
    }
}
