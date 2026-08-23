package com.example.zhixue;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import com.example.zhixue.backend.BackendPlugin;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "zhixue/backend";
    private static final int REQ_NOTIF = 1001;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Android 13+ 必须运行时申请通知权限，否则横幅通知不会显示
        requestNotificationPermissionIfNeeded();
    }

    /** Android 13+ 首次启动若未授权 POST_NOTIFICATIONS，主动请求一次 */
    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQ_NOTIF);
            }
        }
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel channel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        // 传入 Activity 引用，便于 BackendPlugin 做权限检查与跳转系统设置
        BackendPlugin plugin = new BackendPlugin(this);
        channel.setMethodCallHandler(plugin);
    }
}
