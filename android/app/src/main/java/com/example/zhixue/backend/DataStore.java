package com.example.zhixue.backend;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 数据持久化与业务逻辑层。
 * 使用 SharedPreferences + org.json（Android 自带），不依赖 SQLite。
 *
 * 存储 key：
 *  - initialized       : boolean
 *  - users             : JSONArray 字符串  [{account,password,nickname}]
 *  - tasks             : JSONArray 字符串  [{id,owner,name,start_date,end_date,start_time,end_time,week_days,created_at}]
 *  - checkins          : JSONArray 字符串  [{id,owner,task_id,task_name,date,duration_seconds,created_at}]
 *  - reward_log        : JSONArray 字符串  [{owner,date}]
 *  - pet_<account>     : JSONObject 字符串 {owner,pet_type,pet_name,pet_exp,pet_level}
 *  - profile_<account> : JSONObject 字符串 {owner,nickname}
 */
public class DataStore {

    private static final String PREF = "zhixue_store";
    private static final String KEY_INITIALIZED = "initialized";
    private static final String KEY_USERS = "users";
    private static final String KEY_TASKS = "tasks";
    private static final String KEY_CHECKINS = "checkins";
    private static final String KEY_REWARD_LOG = "reward_log";
    private static final String KEY_SIGNIN_LOG = "signin_log";
    private static final String KEY_PET_PREFIX = "pet_";
    private static final String KEY_PROFILE_PREFIX = "profile_";
    private static final String KEY_REMIND_PREFIX = "remind_";   // remind_<account> = JSONObject
    private static final String KEY_SESSION = "session";          // {account, password} 持久化登录

    /** 每次领取奖励增加的经验值 */
    public static final int REWARD_EXP = 20;
    /** 签到获得经验 */
    public static final int SIGNIN_EXP = 20;
    /** 升级所需经验阈值 */
    public static final int LEVEL_UP_THRESHOLD = 100;

    private final Context appCtx;
    private final SharedPreferences sp;

    public DataStore(Context ctx) {
        this.appCtx = ctx.getApplicationContext();
        this.sp = appCtx.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public Context getAppContext() { return appCtx; }

    // ========================= 初始化 =========================

    /** 首次启动写入测试账号 test/123456 及默认宠物 */
    public void ensureInitialized() {
        if (sp.getBoolean(KEY_INITIALIZED, false)) return;
        try {
            JSONArray users = new JSONArray();
            users.put(new JSONObject()
                    .put("account", "test")
                    .put("password", "123456")
                    .put("nickname", "至学学员"));
            sp.edit()
                    .putString(KEY_USERS, users.toString())
                    .putBoolean(KEY_INITIALIZED, true)
                    .apply();

            JSONObject pet = new JSONObject()
                    .put("owner", "test")
                    .put("pet_type", "小猫")
                    .put("pet_name", "小猫咪")
                    .put("pet_exp", 0)
                    .put("pet_level", 1);
            sp.edit().putString(KEY_PET_PREFIX + "test", pet.toString()).apply();

            JSONObject profile = new JSONObject()
                    .put("owner", "test")
                    .put("nickname", "至学学员");
            sp.edit().putString(KEY_PROFILE_PREFIX + "test", profile.toString()).apply();
        } catch (Exception e) {
            throw new RuntimeException("初始化失败", e);
        }
    }

    // ========================= 登录 =========================

    /** 登录校验，成功返回用户 JSONObject（含 account,nickname） */
    public JSONObject login(String account, String password) throws Exception {
        JSONArray users = new JSONArray(sp.getString(KEY_USERS, "[]"));
        for (int i = 0; i < users.length(); i++) {
            JSONObject u = users.getJSONObject(i);
            if (u.getString("account").equals(account)
                    && u.getString("password").equals(password)) {
                return u;
            }
        }
        throw new Exception("账号或密码错误");
    }

    /** 账号是否已存在 */
    public boolean accountExists(String account) throws Exception {
        JSONArray users = new JSONArray(sp.getString(KEY_USERS, "[]"));
        for (int i = 0; i < users.length(); i++) {
            if (account.equals(users.getJSONObject(i).getString("account"))) {
                return true;
            }
        }
        return false;
    }

    // ========================= 登录状态持久化 =========================

    /** 保存登录 session（登录成功后调用） */
    public void saveSession(String account, String password) {
        try {
            JSONObject s = new JSONObject()
                    .put("account", account)
                    .put("password", password);
            sp.edit().putString(KEY_SESSION, s.toString()).apply();
        } catch (Exception ignored) {}
    }

    /** 清除登录 session（登出时调用） */
    public void clearSession() {
        sp.edit().remove(KEY_SESSION).apply();
    }

    /** 读取保存的 session，无则返回 null */
    public JSONObject getSavedSession() {
        String raw = sp.getString(KEY_SESSION, null);
        if (raw == null) return null;
        try {
            return new JSONObject(raw);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 注册新用户。
     * @param account   账号（手机号或邮箱）
     * @param password  密码
     * @param nickname  账号昵称
     * @param petName   宠物名称
     * @return 注册结果 {success, account, nickname, pet_name, pet_type}
     */
    public JSONObject register(String account, String password, String nickname, String petName) throws Exception {
        if (account == null || account.trim().isEmpty()) {
            throw new Exception("账号不能为空");
        }
        if (password == null || password.isEmpty()) {
            throw new Exception("密码不能为空");
        }
        if (nickname == null || nickname.trim().isEmpty()) {
            throw new Exception("昵称不能为空");
        }
        if (petName == null || petName.trim().isEmpty()) {
            throw new Exception("宠物名称不能为空");
        }
        if (accountExists(account)) {
            throw new Exception("该账号已被注册");
        }
        // 写入用户
        JSONArray users = new JSONArray(sp.getString(KEY_USERS, "[]"));
        users.put(new JSONObject()
                .put("account", account)
                .put("password", password)
                .put("nickname", nickname));
        sp.edit().putString(KEY_USERS, users.toString()).apply();
        // 初始化默认宠物（小猫，用户自定义名称）
        JSONObject pet = new JSONObject()
                .put("owner", account)
                .put("pet_type", "小猫")
                .put("pet_name", petName)
                .put("pet_exp", 0)
                .put("pet_level", 1);
        sp.edit().putString(KEY_PET_PREFIX + account, pet.toString()).apply();
        // 初始化资料
        JSONObject profile = new JSONObject()
                .put("owner", account)
                .put("nickname", nickname)
                .put("avatar", "student");
        sp.edit().putString(KEY_PROFILE_PREFIX + account, profile.toString()).apply();
        // 初始化空提醒设置
        JSONObject remind = new JSONObject()
                .put("owner", account)
                .put("remind_enabled", false)
                .put("in_app_remind", false)
                .put("banner_remind", false)
                .put("remind_time", "20:00");
        sp.edit().putString(KEY_REMIND_PREFIX + account, remind.toString()).apply();

        return new JSONObject()
                .put("success", true)
                .put("account", account)
                .put("nickname", nickname)
                .put("pet_name", petName)
                .put("pet_type", "小猫");
    }

    // ========================= 任务 =========================

    /** 获取某用户全部任务（带整体进度 progress 0..1） */
    public JSONArray getAllTasks(String owner) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_TASKS, "[]"));
        JSONArray out = new JSONArray();
        String today = DateUtils.today();
        for (int i = 0; i < all.length(); i++) {
            JSONObject t = all.getJSONObject(i);
            if (!owner.equals(t.getString("owner"))) continue;
            double progress = calcTaskProgress(owner, t, today);
            out.put(new JSONObject()
                    .put("id", t.getString("id"))
                    .put("name", t.getString("name"))
                    .put("start_date", t.getString("start_date"))
                    .put("end_date", t.getString("end_date"))
                    .put("start_time", t.getString("start_time"))
                    .put("end_time", t.getString("end_time"))
                    .put("week_days", t.getJSONArray("week_days"))
                    .put("progress", progress));
        }
        return out;
    }

    /** 获取某用户某日应执行的任务（含 finished/progress）
     *  progress = 当日累计实际学习秒数 / 任务计划秒数
     *  finished = 当日累计实际学习秒数 >= 任务计划秒数
     */
    public JSONArray getTasksForDate(String owner, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_TASKS, "[]"));
        JSONArray out = new JSONArray();
        int isoDow = DateUtils.isoWeekday(DateUtils.parseYMD(dateYMD));
        for (int i = 0; i < all.length(); i++) {
            JSONObject t = all.getJSONObject(i);
            if (!owner.equals(t.getString("owner"))) continue;
            String sd = t.getString("start_date");
            String ed = t.getString("end_date");
            if (dateYMD.compareTo(sd) < 0 || dateYMD.compareTo(ed) > 0) continue;
            JSONArray wd = t.getJSONArray("week_days");
            boolean match = false;
            for (int j = 0; j < wd.length(); j++) {
                if (wd.getInt(j) == isoDow) { match = true; break; }
            }
            if (!match) continue;
            String taskId = t.getString("id");
            String startTime = t.getString("start_time");
            String endTime = t.getString("end_time");
            int planned = plannedDurationSeconds(startTime, endTime);
            if (planned <= 0) planned = 60; // 至少1分钟兜底
            int actual = accumulatedSeconds(owner, taskId, dateYMD);
            double progress = planned == 0 ? 0.0 : Math.min(1.0, (double) actual / (double) planned);
            boolean finished = actual >= planned;
            out.put(new JSONObject()
                    .put("id", taskId)
                    .put("name", t.getString("name"))
                    .put("finished", finished)
                    .put("progress", progress)
                    .put("planned_seconds", planned)
                    .put("accumulated_seconds", actual)
                    .put("start_time", startTime)
                    .put("end_time", endTime));
        }
        return out;
    }

    /** 解析 "HH:MM" 计划时段得到总秒数 */
    public int plannedDurationSeconds(String startTime, String endTime) throws Exception {
        int[] s = parseHHMM(startTime);
        int[] e = parseHHMM(endTime);
        int secs = (e[0] * 3600 + e[1] * 60) - (s[0] * 3600 + s[1] * 60);
        if (secs <= 0) secs += 24 * 3600; // 跨午夜
        return secs;
    }

    private int[] parseHHMM(String hhmm) {
        try {
            String[] parts = hhmm.split(":");
            int h = Integer.parseInt(parts[0]);
            int m = Integer.parseInt(parts[1]);
            return new int[]{h, m};
        } catch (Exception e) {
            return new int[]{0, 0};
        }
    }

    /** 某任务某日累计学习秒数（同任务+同日下所有打卡记录累加） */
    public int accumulatedSeconds(String owner, String taskId, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        int sum = 0;
        for (int i = 0; i < all.length(); i++) {
            JSONObject c = all.getJSONObject(i);
            if (owner.equals(c.optString("owner"))
                    && taskId.equals(c.optString("task_id"))
                    && dateYMD.equals(c.optString("date"))) {
                sum += c.optInt("duration_seconds", 0);
            }
        }
        return sum;
    }

    /** 创建任务，返回新任务 JSONObject（含 id） */
    public JSONObject createTask(String owner, String name, String startDate, String endDate,
                                 String startTime, String endTime, List<Integer> weekDays) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_TASKS, "[]"));
        String id = "task_" + System.currentTimeMillis();
        JSONArray wdArr = new JSONArray();
        for (int d : weekDays) wdArr.put(d);
        JSONObject t = new JSONObject()
                .put("id", id)
                .put("owner", owner)
                .put("name", name)
                .put("start_date", startDate)
                .put("end_date", endDate)
                .put("start_time", startTime)
                .put("end_time", endTime)
                .put("week_days", wdArr)
                .put("created_at", System.currentTimeMillis());
        all.put(t);
        sp.edit().putString(KEY_TASKS, all.toString()).apply();
        return new JSONObject().put("success", true).put("id", id);
    }

    // ========================= 打卡 =========================

    /** 添加一条打卡记录 */
    public JSONObject addCheckin(String owner, String taskId, String taskName,
                                 int durationSeconds, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        String id = "ck_" + System.currentTimeMillis();
        JSONObject c = new JSONObject()
                .put("id", id)
                .put("owner", owner)
                .put("task_id", taskId)
                .put("task_name", taskName)
                .put("date", dateYMD)
                .put("duration_seconds", durationSeconds)
                .put("created_at", System.currentTimeMillis());
        all.put(c);
        sp.edit().putString(KEY_CHECKINS, all.toString()).apply();

        // 返回当前奖励是否可领取（前端可据此提示）
        boolean claimable = isRewardClaimable(owner, dateYMD);
        return new JSONObject().put("success", true).put("reward_claimable", claimable);
    }

    /** 清除某用户某日某任务的所有打卡记录（用于重置今日进度） */
    public JSONObject clearCheckins(String owner, String taskId, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        JSONArray kept = new JSONArray();
        int removed = 0;
        for (int i = 0; i < all.length(); i++) {
            JSONObject c = all.getJSONObject(i);
            boolean match = owner.equals(c.optString("owner"))
                    && taskId.equals(c.optString("task_id"))
                    && dateYMD.equals(c.optString("date"));
            if (match) {
                removed++;
            } else {
                kept.put(c);
            }
        }
        sp.edit().putString(KEY_CHECKINS, kept.toString()).apply();
        return new JSONObject().put("success", true).put("removed", removed);
    }

    /** 清除某用户某日所有任务的打卡记录 */
    public JSONObject clearAllCheckinsOnDate(String owner, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        JSONArray kept = new JSONArray();
        int removed = 0;
        for (int i = 0; i < all.length(); i++) {
            JSONObject c = all.getJSONObject(i);
            if (owner.equals(c.optString("owner")) && dateYMD.equals(c.optString("date"))) {
                removed++;
            } else {
                kept.put(c);
            }
        }
        sp.edit().putString(KEY_CHECKINS, kept.toString()).apply();
        // 同时清除当日奖励领取记录
        JSONArray log = new JSONArray(sp.getString(KEY_REWARD_LOG, "[]"));
        JSONArray keptLog = new JSONArray();
        for (int i = 0; i < log.length(); i++) {
            JSONObject e = log.getJSONObject(i);
            if (!(owner.equals(e.optString("owner")) && dateYMD.equals(e.optString("date")))) {
                keptLog.put(e);
            }
        }
        sp.edit().putString(KEY_REWARD_LOG, keptLog.toString()).apply();
        return new JSONObject().put("success", true).put("removed", removed);
    }

    /** 获取全部打卡记录（倒序，最新的在前），附带任务的计划 start_time/end_time */
    public JSONArray getAllCheckins(String owner) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        JSONArray tasksArr = new JSONArray(sp.getString(KEY_TASKS, "[]"));
        java.util.Map<String, JSONObject> taskIndex = new java.util.HashMap<>();
        for (int i = 0; i < tasksArr.length(); i++) {
            JSONObject t = tasksArr.getJSONObject(i);
            taskIndex.put(t.getString("id"), t);
        }
        JSONArray out = new JSONArray();
        // 倒序收集
        for (int i = all.length() - 1; i >= 0; i--) {
            JSONObject c = all.getJSONObject(i);
            if (owner.equals(c.getString("owner"))) {
                JSONObject row = new JSONObject()
                        .put("id", c.getString("id"))
                        .put("date", c.getString("date"))
                        .put("task_name", c.getString("task_name"))
                        .put("duration_seconds", c.optInt("duration_seconds", 0));
                JSONObject t = taskIndex.get(c.optString("task_id", ""));
                if (t != null) {
                    row.put("start_time", t.optString("start_time", ""));
                    row.put("end_time", t.optString("end_time", ""));
                } else {
                    row.put("start_time", "").put("end_time", "");
                }
            }
        }
        return out;
    }

    /** 某任务在某日是否已打卡 */
    public boolean hasCheckinOnDate(String owner, String taskId, String dateYMD) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        for (int i = 0; i < all.length(); i++) {
            JSONObject c = all.getJSONObject(i);
            if (owner.equals(c.getString("owner"))
                    && taskId.equals(c.getString("task_id"))
                    && dateYMD.equals(c.getString("date"))) {
                return true;
            }
        }
        return false;
    }

    // ========================= 日历聚合 =========================

    /** 获取某月打卡日历数据 [{date, study_minute, tasks:[name]}] */
    public JSONArray getCalendarData(String owner, int year, int month) throws Exception {
        JSONArray all = new JSONArray(sp.getString(KEY_CHECKINS, "[]"));
        // 按 date 聚合
        java.util.Map<String, JSONObject> agg = new java.util.LinkedHashMap<>();
        for (int i = 0; i < all.length(); i++) {
            JSONObject c = all.getJSONObject(i);
            if (!owner.equals(c.getString("owner"))) continue;
            String date = c.getString("date");
            if (!date.startsWith(String.format("%04d-%02d", year, month))) continue;
            JSONObject day = agg.get(date);
            if (day == null) {
                day = new JSONObject()
                        .put("date", date)
                        .put("study_minute", 0)
                        .put("tasks", new JSONArray());
                agg.put(date, day);
            }
            day.put("study_minute", day.getInt("study_minute") + c.optInt("duration_seconds", 0) / 60);
            JSONArray tasks = day.getJSONArray("tasks");
            String name = c.getString("task_name");
            // 避免同一天同任务重复
            boolean exists = false;
            for (int j = 0; j < tasks.length(); j++) {
                if (tasks.getString(j).equals(name)) { exists = true; break; }
            }
            if (!exists) tasks.put(name);
        }
        JSONArray out = new JSONArray();
        for (JSONObject v : agg.values()) out.put(v);
        return out;
    }

    // ========================= 连续打卡 =========================

    /** 连续签到天数：基于 signin_log 计算 */
    public int getStreak(String owner) throws Exception {
        JSONArray log = new JSONArray(sp.getString(KEY_SIGNIN_LOG, "[]"));
        Set<String> dates = new HashSet<>();
        for (int i = 0; i < log.length(); i++) {
            JSONObject e = log.getJSONObject(i);
            if (owner.equals(e.getString("owner"))) dates.add(e.getString("date"));
        }
        return DateUtils.calcStreak(dates);
    }

    /** 今日是否已签到 */
    public boolean isSignedIn(String owner, String dateYMD) throws Exception {
        JSONArray log = new JSONArray(sp.getString(KEY_SIGNIN_LOG, "[]"));
        for (int i = 0; i < log.length(); i++) {
            JSONObject e = log.getJSONObject(i);
            if (owner.equals(e.getString("owner")) && dateYMD.equals(e.getString("date"))) {
                return true;
            }
        }
        return false;
    }

    /** 签到：不检查任务完成，直接加经验+写签到记录 */
    public JSONObject signIn(String owner, String dateYMD) throws Exception {
        if (isSignedIn(owner, dateYMD)) {
            throw new Exception("今日已签到");
        }
        JSONObject pet = getPet(owner);
        int level = pet.getInt("pet_level");
        int exp = pet.getInt("pet_exp") + SIGNIN_EXP;
        boolean leveledUp = false;
        while (exp >= LEVEL_UP_THRESHOLD) {
            exp -= LEVEL_UP_THRESHOLD;
            level++;
            leveledUp = true;
        }
        pet.put("pet_exp", exp).put("pet_level", level);
        sp.edit().putString(KEY_PET_PREFIX + owner, pet.toString()).apply();

        JSONArray log = new JSONArray(sp.getString(KEY_SIGNIN_LOG, "[]"));
        log.put(new JSONObject().put("owner", owner).put("date", dateYMD));
        sp.edit().putString(KEY_SIGNIN_LOG, log.toString()).apply();

        return new JSONObject()
                .put("success", true)
                .put("exp_gained", SIGNIN_EXP)
                .put("pet_exp", exp)
                .put("pet_level", level)
                .put("leveled_up", leveledUp)
                .put("streak", getStreak(owner));
    }

    // ========================= 每日奖励 =========================

    /** 今日奖励是否已领取 */
    public boolean isRewardClaimed(String owner, String dateYMD) throws Exception {
        JSONArray log = new JSONArray(sp.getString(KEY_REWARD_LOG, "[]"));
        for (int i = 0; i < log.length(); i++) {
            JSONObject e = log.getJSONObject(i);
            if (owner.equals(e.getString("owner")) && dateYMD.equals(e.getString("date"))) {
                return true;
            }
        }
        return false;
    }

    /** 今日奖励状态 {total, finished, claimable, already_claimed, signed_in} */
    public JSONObject getRewardStatus(String owner, String dateYMD) throws Exception {
        JSONArray todayTasks = getTasksForDate(owner, dateYMD);
        int total = todayTasks.length();
        int finished = 0;
        for (int i = 0; i < todayTasks.length(); i++) {
            if (todayTasks.getJSONObject(i).getBoolean("finished")) finished++;
        }
        boolean already = isRewardClaimed(owner, dateYMD);
        boolean claimable = total > 0 && finished == total && !already;
        boolean signedIn = isSignedIn(owner, dateYMD);
        return new JSONObject()
                .put("total", total)
                .put("finished", finished)
                .put("claimable", claimable)
                .put("already_claimed", already)
                .put("signed_in", signedIn);
    }

    /** 今日奖励是否可领取（不抛错，仅判断） */
    private boolean isRewardClaimable(String owner, String dateYMD) throws Exception {
        return getRewardStatus(owner, dateYMD).getBoolean("claimable");
    }

    /** 领取今日奖励：校验未领过 + 今日任务非空 + 全部完成 → 加经验升级 */
    public JSONObject claimDailyReward(String owner, String dateYMD) throws Exception {
        if (isRewardClaimed(owner, dateYMD)) {
            throw new Exception("今日奖励已领取");
        }
        JSONArray todayTasks = getTasksForDate(owner, dateYMD);
        if (todayTasks.length() == 0) {
            throw new Exception("今日暂无任务，无法领取");
        }
        for (int i = 0; i < todayTasks.length(); i++) {
            String tid = todayTasks.getJSONObject(i).getString("id");
            if (!hasCheckinOnDate(owner, tid, dateYMD)) {
                throw new Exception("今日还有未完成任务");
            }
        }

        JSONObject pet = getPet(owner);
        int level = pet.getInt("pet_level");
        int exp = pet.getInt("pet_exp") + REWARD_EXP;
        boolean leveledUp = false;
        while (exp >= LEVEL_UP_THRESHOLD) {
            exp -= LEVEL_UP_THRESHOLD;
            level++;
            leveledUp = true;
        }
        pet.put("pet_exp", exp).put("pet_level", level);
        sp.edit().putString(KEY_PET_PREFIX + owner, pet.toString()).apply();

        JSONArray log = new JSONArray(sp.getString(KEY_REWARD_LOG, "[]"));
        log.put(new JSONObject().put("owner", owner).put("date", dateYMD));
        sp.edit().putString(KEY_REWARD_LOG, log.toString()).apply();

        return new JSONObject()
                .put("success", true)
                .put("exp_gained", REWARD_EXP)
                .put("pet_exp", exp)
                .put("pet_level", level)
                .put("leveled_up", leveledUp);
    }

    // ========================= 宠物 / 资料 =========================

    public JSONObject getPet(String owner) throws Exception {
        String raw = sp.getString(KEY_PET_PREFIX + owner, null);
        if (raw != null) return new JSONObject(raw);
        // 兜底：创建默认宠物
        JSONObject pet = new JSONObject()
                .put("owner", owner)
                .put("pet_type", "小猫")
                .put("pet_name", "小猫咪")
                .put("pet_exp", 0)
                .put("pet_level", 1);
        sp.edit().putString(KEY_PET_PREFIX + owner, pet.toString()).apply();
        return pet;
    }

    /** 更新宠物（仅传哪个改哪个），返回最新宠物信息 */
    public JSONObject updatePet(String owner, String petType, String petName) throws Exception {
        JSONObject pet = getPet(owner);
        if (petType != null && !petType.isEmpty()) pet.put("pet_type", petType);
        if (petName != null && !petName.isEmpty()) pet.put("pet_name", petName);
        sp.edit().putString(KEY_PET_PREFIX + owner, pet.toString()).apply();
        return new JSONObject()
                .put("success", true)
                .put("pet_type", pet.getString("pet_type"))
                .put("pet_name", pet.getString("pet_name"))
                .put("pet_exp", pet.getInt("pet_exp"))
                .put("pet_level", pet.getInt("pet_level"));
    }

    /** 合并资料：account + nickname + avatar + pet + streak */
    public JSONObject getProfile(String owner) throws Exception {
        String nickname = owner;
        String avatar = "student";
        String rawProfile = sp.getString(KEY_PROFILE_PREFIX + owner, null);
        if (rawProfile != null) {
            JSONObject p = new JSONObject(rawProfile);
            nickname = p.optString("nickname", owner);
            avatar = p.optString("avatar", "student");
        } else {
            // 兜底从 users 取
            JSONArray users = new JSONArray(sp.getString(KEY_USERS, "[]"));
            for (int i = 0; i < users.length(); i++) {
                JSONObject u = users.getJSONObject(i);
                if (owner.equals(u.getString("account"))) {
                    nickname = u.optString("nickname", owner);
                    break;
                }
            }
        }
        JSONObject pet = getPet(owner);
        return new JSONObject()
                .put("account", owner)
                .put("nickname", nickname)
                .put("avatar", avatar)
                .put("pet_type", pet.getString("pet_type"))
                .put("pet_name", pet.getString("pet_name"))
                .put("pet_exp", pet.getInt("pet_exp"))
                .put("pet_level", pet.getInt("pet_level"))
                .put("streak", getStreak(owner));
    }

    /** 更新用户资料（昵称 / 头像），仅传哪个改哪个 */
    public JSONObject updateProfile(String owner, String nickname, String avatar) throws Exception {
        JSONObject p;
        String raw = sp.getString(KEY_PROFILE_PREFIX + owner, null);
        if (raw != null) {
            p = new JSONObject(raw);
        } else {
            p = new JSONObject().put("owner", owner).put("nickname", owner).put("avatar", "student");
        }
        if (nickname != null && !nickname.isEmpty()) p.put("nickname", nickname);
        if (avatar != null && !avatar.isEmpty()) p.put("avatar", avatar);
        sp.edit().putString(KEY_PROFILE_PREFIX + owner, p.toString()).apply();
        return new JSONObject()
                .put("success", true)
                .put("nickname", p.optString("nickname", owner))
                .put("avatar", p.optString("avatar", "student"));
    }

    // ========================= 内部计算 =========================

    /**
     * 任务整体进度 = completedDays / scheduledDaysSoFar
     * scheduledDaysSoFar: [start_date, min(today, end_date)] 区间内 ISO 星期 ∈ week_days 的天数
     * completedDays: 上述天数中累计实际学习秒数 >= 计划时段秒数 的天数
     */
    private double calcTaskProgress(String owner, JSONObject task, String today) throws Exception {
        String sd = task.getString("start_date");
        String ed = task.getString("end_date");
        String startTime = task.optString("start_time", "08:00");
        String endTime = task.optString("end_time", "09:00");
        List<Integer> weekDays = new ArrayList<>();
        JSONArray wd = task.getJSONArray("week_days");
        for (int j = 0; j < wd.length(); j++) weekDays.add(wd.getInt(j));

        String upper = today.compareTo(ed) > 0 ? ed : today;
        if (today.compareTo(sd) < 0) return 0.0;

        String taskId = task.getString("id");
        int planned = plannedDurationSeconds(startTime, endTime);
        if (planned <= 0) planned = 60;

        int scheduled = 0;
        int completed = 0;
        String cursor = sd;
        int guard = 0;
        while (cursor.compareTo(upper) <= 0 && guard < 100000) {
            if (DateUtils.isScheduledOn(cursor, sd, ed, weekDays)) {
                scheduled++;
                if (accumulatedSeconds(owner, taskId, cursor) >= planned) completed++;
            }
            cursor = DateUtils.plusOneDay(cursor);
            guard++;
        }
        return scheduled == 0 ? 0.0 : (double) completed / (double) scheduled;
    }

    // ========================= 提醒设置 =========================

    private static final String DEFAULT_REMIND_TIME = "08:00";

    /** 获取提醒设置 {remindEnabled, inAppRemind, bannerRemind, remindTime} */
    public JSONObject getReminderSettings(String owner) throws Exception {
        String raw = sp.getString(KEY_REMIND_PREFIX + owner, null);
        if (raw == null) {
            JSONObject d = new JSONObject()
                    .put("remindEnabled", false)
                    .put("inAppRemind", true)
                    .put("bannerRemind", false)
                    .put("remindTime", DEFAULT_REMIND_TIME);
            sp.edit().putString(KEY_REMIND_PREFIX + owner, d.toString()).apply();
            return d;
        }
        return new JSONObject(raw);
    }

    /** 保存提醒设置并重新调度（默认值兜底） */
    public JSONObject saveReminderSettings(String owner, Boolean remindEnabled, Boolean inAppRemind,
                                           Boolean bannerRemind, String remindTime) throws Exception {
        JSONObject cur = getReminderSettings(owner);
        if (remindEnabled != null) cur.put("remindEnabled", remindEnabled);
        if (inAppRemind != null) cur.put("inAppRemind", inAppRemind);
        if (bannerRemind != null) cur.put("bannerRemind", bannerRemind);
        if (remindTime != null && !remindTime.isEmpty()) cur.put("remindTime", remindTime);
        sp.edit().putString(KEY_REMIND_PREFIX + owner, cur.toString()).apply();

        // 立即重调度
        JSONArray allTasks = getAllTasks(owner);
        ReminderScheduler.rescheduleAll(appCtx, cur, owner, allTasks);
        return new JSONObject().put("success", true);
    }
}
