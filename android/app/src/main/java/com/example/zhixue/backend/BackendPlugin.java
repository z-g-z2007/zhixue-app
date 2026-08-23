package com.example.zhixue.backend;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Build;
import android.provider.Settings;

import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Flutter MethodChannel 入口。
 * 通道名：zhixue/backend
 * 内存中持有 currentAccount（login 时设置，logout 时清空），
 * 所有非 init/login 方法先 requireLogin() 校验。
 * JSONObject/JSONArray 递归转为 Map/List 后回传 Flutter。
 */
public class BackendPlugin implements MethodChannel.MethodCallHandler {

    private final DataStore store;
    private final Context context;
    private final Activity activity;
    private String currentAccount = null;

    public BackendPlugin(Activity activity) {
        this.activity = activity;
        this.context = activity.getApplicationContext();
        this.store = new DataStore(context);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "init":
                    store.ensureInitialized();
                    result.success(true);
                    return;

                case "login": {
                    String account = call.argument("account");
                    String password = call.argument("password");
                    JSONObject u = store.login(account, password);
                    currentAccount = account;
                    // 持久化登录 session
                    store.saveSession(account, password);
                    // 返回登录综合信息
                    JSONObject pet = store.getPet(account);
                    int streak = store.getStreak(account);
                    JSONObject out = new JSONObject()
                            .put("account", u.getString("account"))
                            .put("nickname", u.optString("nickname", account))
                            .put("avatar", store.getProfile(account).optString("avatar", "student"))
                            .put("pet_type", pet.getString("pet_type"))
                            .put("pet_name", pet.getString("pet_name"))
                            .put("pet_exp", pet.getInt("pet_exp"))
                            .put("pet_level", pet.getInt("pet_level"))
                            .put("streak", streak);
                    result.success(toMap(out));
                    // 登录后立即重新调度提醒
                    try {
                        JSONObject s = store.getReminderSettings(currentAccount);
                        JSONArray ts = store.getAllTasks(currentAccount);
                        ReminderScheduler.rescheduleAll(store.getAppContext(), s, currentAccount, ts);
                    } catch (Exception ignore) {}
                    return;
                }

                case "restoreSession": {
                    // 启动时自动恢复登录状态
                    JSONObject session = store.getSavedSession();
                    if (session == null) {
                        result.success(null);
                        return;
                    }
                    String account = session.getString("account");
                    String password = session.getString("password");
                    try {
                        JSONObject u = store.login(account, password);
                        currentAccount = account;
                        JSONObject pet = store.getPet(account);
                        int streak = store.getStreak(account);
                        JSONObject out = new JSONObject()
                                .put("account", u.getString("account"))
                                .put("nickname", u.optString("nickname", account))
                                .put("avatar", store.getProfile(account).optString("avatar", "student"))
                                .put("pet_type", pet.getString("pet_type"))
                                .put("pet_name", pet.getString("pet_name"))
                                .put("pet_exp", pet.getInt("pet_exp"))
                                .put("pet_level", pet.getInt("pet_level"))
                                .put("streak", streak);
                        result.success(toMap(out));
                        // 恢复后重新调度提醒
                        try {
                            JSONObject s = store.getReminderSettings(currentAccount);
                            JSONArray ts = store.getAllTasks(currentAccount);
                            ReminderScheduler.rescheduleAll(store.getAppContext(), s, currentAccount, ts);
                        } catch (Exception ignore) {}
                    } catch (Exception e) {
                        // session 失效（密码改了等），清除
                        store.clearSession();
                        result.success(null);
                    }
                    return;
                }

                case "register": {
                    String account = call.argument("account");
                    String password = call.argument("password");
                    String nickname = call.argument("nickname");
                    String petName = call.argument("pet_name");
                    JSONObject r = store.register(account, password, nickname, petName);
                    result.success(toMap(r));
                    return;
                }

                case "accountExists": {
                    String account = call.argument("account");
                    result.success(store.accountExists(account));
                    return;
                }

                case "getTodayTasks": {
                    requireLogin();
                    JSONArray arr = store.getTasksForDate(currentAccount, DateUtils.today());
                    result.success(toList(arr));
                    return;
                }

                case "getAllTasks": {
                    requireLogin();
                    JSONArray arr = store.getAllTasks(currentAccount);
                    result.success(toList(arr));
                    return;
                }

                case "createTask": {
                    requireLogin();
                    String name = call.argument("name");
                    String startDate = call.argument("start_date");
                    String endDate = call.argument("end_date");
                    String startTime = call.argument("start_time");
                    String endTime = call.argument("end_time");
                    List<Integer> weekDays = call.argument("week_days");
                    if (weekDays == null) weekDays = new ArrayList<>();
                    JSONObject r = store.createTask(currentAccount, name, startDate, endDate,
                            startTime, endTime, weekDays);
                    result.success(toMap(r));
                    // 新建任务后重新调度提醒
                    try {
                        JSONObject s = store.getReminderSettings(currentAccount);
                        JSONArray ts = store.getAllTasks(currentAccount);
                        ReminderScheduler.rescheduleAll(store.getAppContext(), s, currentAccount, ts);
                    } catch (Exception ignore) {}
                    return;
                }

                case "addCheckin": {
                    requireLogin();
                    String taskId = call.argument("task_id");
                    String taskName = call.argument("task_name");
                    int durationSeconds = call.argument("duration_seconds");
                    String date = call.argument("date");
                    JSONObject r = store.addCheckin(currentAccount, taskId, taskName, durationSeconds, date);
                    result.success(toMap(r));
                    return;
                }

                case "getCheckinRecords": {
                    requireLogin();
                    JSONArray arr = store.getAllCheckins(currentAccount);
                    result.success(toList(arr));
                    return;
                }

                case "getCalendarData": {
                    requireLogin();
                    int year = call.argument("year");
                    int month = call.argument("month");
                    JSONArray arr = store.getCalendarData(currentAccount, year, month);
                    result.success(toList(arr));
                    return;
                }

                case "getStreak": {
                    requireLogin();
                    result.success(store.getStreak(currentAccount));
                    return;
                }

                case "getRewardStatus": {
                    requireLogin();
                    JSONObject r = store.getRewardStatus(currentAccount, DateUtils.today());
                    result.success(toMap(r));
                    return;
                }

                case "claimDailyReward": {
                    requireLogin();
                    JSONObject r = store.claimDailyReward(currentAccount, DateUtils.today());
                    result.success(toMap(r));
                    return;
                }

                case "getPetInfo": {
                    requireLogin();
                    JSONObject pet = store.getPet(currentAccount);
                    result.success(toMap(pet));
                    return;
                }

                case "updatePet": {
                    requireLogin();
                    String petType = call.argument("pet_type");
                    String petName = call.argument("pet_name");
                    JSONObject r = store.updatePet(currentAccount, petType, petName);
                    result.success(toMap(r));
                    return;
                }

                case "getProfile": {
                    requireLogin();
                    JSONObject r = store.getProfile(currentAccount);
                    result.success(toMap(r));
                    return;
                }

                case "updateProfile": {
                    requireLogin();
                    String nickname = call.argument("nickname");
                    String avatar = call.argument("avatar");
                    JSONObject r = store.updateProfile(currentAccount, nickname, avatar);
                    result.success(toMap(r));
                    return;
                }

                case "isAirplaneModeOn": {
                    boolean on = isAirplaneModeOn();
                    result.success(on);
                    return;
                }

                case "setAirplaneMode": {
                    Boolean enable = call.argument("enable");
                    boolean want = enable != null && enable;
                    JSONObject r = setAirplaneModeImpl(want);
                    result.success(toMap(r));
                    return;
                }

                case "signIn": {
                    requireLogin();
                    String date = call.argument("date");
                    if (date == null) date = DateUtils.today();
                    JSONObject r = store.signIn(currentAccount, date);
                    result.success(toMap(r));
                    return;
                }

                case "clearTodayCheckins": {
                    requireLogin();
                    String taskId = call.argument("task_id");
                    String date = call.argument("date");
                    if (date == null) date = DateUtils.today();
                    JSONObject r;
                    if (taskId != null && !taskId.isEmpty()) {
                        r = store.clearCheckins(currentAccount, taskId, date);
                    } else {
                        r = store.clearAllCheckinsOnDate(currentAccount, date);
                    }
                    result.success(toMap(r));
                    return;
                }

                case "logout": {
                    currentAccount = null;
                    store.clearSession();
                    result.success(true);
                    return;
                }

                case "getReminderSettings": {
                    requireLogin();
                    JSONObject s = store.getReminderSettings(currentAccount);
                    result.success(toMap(s));
                    return;
                }

                case "saveReminderSettings": {
                    requireLogin();
                    Boolean re = call.argument("remindEnabled");
                    Boolean ia = call.argument("inAppRemind");
                    Boolean br = call.argument("bannerRemind");
                    String rt = call.argument("remindTime");
                    // DataStore.saveReminderSettings 内部已用最新设置重新调度提醒
                    JSONObject r = store.saveReminderSettings(currentAccount, re, ia, br, rt);
                    result.success(toMap(r));
                    return;
                }

                case "hasNotificationPermission": {
                    result.success(hasNotificationPermission());
                    return;
                }

                case "openNotificationSettings": {
                    boolean opened = openNotificationSettings();
                    result.success(opened);
                    return;
                }

                default:
                    result.notImplemented();
            }
        } catch (Exception e) {
            result.error("BACKEND_ERROR", e.getMessage() == null ? "未知错误" : e.getMessage(), null);
        }
    }

    private void requireLogin() throws Exception {
        if (currentAccount == null) {
            throw new Exception("未登录，请先登录");
        }
    }

    /** JSONObject -> Map（递归），便于 Flutter 直接消费 */
    private static Map<String, Object> toMap(JSONObject o) throws Exception {
        Map<String, Object> map = new HashMap<>();
        java.util.Iterator<String> it = o.keys();
        while (it.hasNext()) {
            String key = it.next();
            Object v = o.get(key);
            map.put(key, convert(v));
        }
        return map;
    }

    /** JSONArray -> List（递归） */
    private static List<Object> toList(JSONArray a) throws Exception {
        List<Object> list = new ArrayList<>();
        for (int i = 0; i < a.length(); i++) {
            list.add(convert(a.get(i)));
        }
        return list;
    }

    /** 递归转换 JSONObject/JSONArray，其余类型原样返回 */
    private static Object convert(Object v) throws Exception {
        if (v instanceof JSONObject) {
            return toMap((JSONObject) v);
        } else if (v instanceof JSONArray) {
            return toList((JSONArray) v);
        } else if (v.equals(JSONObject.NULL)) {
            return null;
        }
        return v;
    }

    // ========================= 通知权限 =========================

    /**
     * 通知权限是否已授予。
     * Android 13+ 检查 POST_NOTIFICATIONS 运行时权限；
     * Android 13- 检查通知是否整体启用（NotificationManagerCompat.areNotificationsEnabled）。
     */
    private boolean hasNotificationPermission() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                return ContextCompat.checkSelfPermission(activity, android.Manifest.permission.POST_NOTIFICATIONS)
                        == PackageManager.PERMISSION_GRANTED;
            }
            // Android 13 以下没有运行时权限，只要通知没被用户在系统设置里整体关闭即可
            return NotificationManagerCompat.from(context).areNotificationsEnabled();
        } catch (Throwable ignored) {
            return false;
        }
    }

    /**
     * 跳转到系统应用通知设置页（让用户手动开启通知）。
     * Android 8+ 用 ACTION_APP_NOTIFICATION_SETTINGS；低版本回退到应用详情页。
     * @return 是否成功拉起设置页
     */
    private boolean openNotificationSettings() {
        try {
            Intent i;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
                i.putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName());
            } else {
                i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                i.setData(android.net.Uri.fromParts("package", context.getPackageName(), null));
            }
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(i);
            return true;
        } catch (Throwable ignored) {
            return false;
        }
    }

    // ========================= 飞行模式 =========================

    /** 当前是否处于飞行模式 */
    private boolean isAirplaneModeOn() {
        // 优先读 Settings.Global.AIRPLANE_MODE_ON（所有安卓版本都能用的标准方式）
        try {
            int val = Settings.Global.getInt(context.getContentResolver(), Settings.Global.AIRPLANE_MODE_ON, 0);
            return val != 0;
        } catch (Throwable ignored) {}
        // 兜底：ConnectivityService（Android 12+ 部分定制 ROM 可能屏蔽 Settings.Global）
        try {
            ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (cm == null) return false;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                android.net.NetworkCapabilities caps = cm.getNetworkCapabilities(cm.getActiveNetwork());
                return caps == null
                        || (!caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                            && !caps.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET));
            } else {
                @SuppressWarnings("deprecation")
                android.net.NetworkInfo ni = cm.getActiveNetworkInfo();
                return ni == null || !ni.isConnectedOrConnecting();
            }
        } catch (Throwable ignored) {
            return false;
        }
    }

    /**
     * 开启/关闭飞行模式。
     * Android 4.2+ 要求 WRITE_SECURE_SETTINGS（系统级权限）才能通过 Settings.Global 直接修改。
     * 普通应用拿不到该权限时：返回 { success: false, need_manual: true }，
     * 前端应弹"请手动开启飞行模式"并跳系统设置 Settings.ACTION_AIRPLANE_MODE_SETTINGS。
     * 如果已处于目标状态，返回 already: true。
     */
    private JSONObject setAirplaneModeImpl(boolean want) throws Exception {
        boolean current = isAirplaneModeOn();
        if (current == want) {
            return new JSONObject()
                    .put("success", true)
                    .put("already", true)
                    .put("now_on", current);
        }
        boolean changed = false;
        Throwable err = null;
        // 1) 尝试直接 Settings.Global 写入（需 WRITE_SECURE_SETTINGS）
        try {
            Settings.Global.putInt(context.getContentResolver(), Settings.Global.AIRPLANE_MODE_ON, want ? 1 : 0);
            // 旧版本广播（Android 8 以下可能还能用）
            try {
                Intent intent = new Intent(Intent.ACTION_AIRPLANE_MODE_CHANGED);
                intent.putExtra("state", want);
                context.sendBroadcast(intent);
            } catch (Throwable ignored) {}
            changed = (isAirplaneModeOn() == want);
        } catch (Throwable e) {
            err = e;
        }
        if (changed) {
            return new JSONObject()
                    .put("success", true)
                    .put("already", false)
                    .put("now_on", want)
                    .put("direct", true);
        }
        // 2) 无法直接修改 → 跳转系统设置页
        try {
            Intent i = new Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS);
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(i);
            return new JSONObject()
                    .put("success", false)
                    .put("already", false)
                    .put("need_manual", true)
                    .put("message", "普通应用无法直接修改飞行模式，请在系统设置中手动切换")
                    .put("launch_settings", true)
                    .put("err", err != null ? err.getMessage() : null)
                    .put("now_on", current);
        } catch (Throwable e2) {
            return new JSONObject()
                    .put("success", false)
                    .put("already", false)
                    .put("need_manual", true)
                    .put("message", "请在系统设置中切换飞行模式：设置 → 网络和互联网 → 飞行模式")
                    .put("err", err != null ? err.getMessage() : null)
                    .put("now_on", current);
        }
    }
}
