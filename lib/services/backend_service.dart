import 'package:flutter/services.dart';

/// Java 本地后端调用封装。
/// 通过 MethodChannel "zhixue/backend" 与 Android Java 端通信。
/// 所有方法失败时抛出 PlatformException（e.message 为中文错误描述）。
class BackendService {
  static const MethodChannel _channel = MethodChannel('zhixue/backend');

  /// 初始化（写入测试账号 test/123456），应用启动时调用一次。
  static Future<void> init() async {
    await _channel.invokeMethod('init');
  }

  /// 登录，返回用户综合信息
  static Future<Map<String, dynamic>> login(String account, String password) async {
    final r = await _channel.invokeMethod('login', {
      'account': account,
      'password': password,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// 注册新用户。返回 {success, account, nickname, pet_name, pet_type}
  static Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    required String nickname,
    required String petName,
  }) async {
    final r = await _channel.invokeMethod('register', {
      'account': account,
      'password': password,
      'nickname': nickname,
      'pet_name': petName,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// 检查账号是否已存在
  static Future<bool> accountExists(String account) async {
    final r = await _channel.invokeMethod('accountExists', {'account': account});
    return r == true;
  }

  /// 启动时恢复登录 session。无保存 session 或失效返回 null，有效则返回登录综合信息
  static Future<Map<String, dynamic>?> restoreSession() async {
    final r = await _channel.invokeMethod('restoreSession');
    if (r == null) return null;
    return Map<String, dynamic>.from(r as Map);
  }

  /// 今日应执行任务列表
  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    final r = await _channel.invokeMethod('getTodayTasks');
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 获取今日某个任务的详情（含 planned_seconds、accumulated_seconds）；找不到返回 null
  static Future<Map<String, dynamic>?> getTodayTaskById(String taskId) async {
    final list = await getTodayTasks();
    try {
      return list.firstWhere((t) => t['id'] == taskId);
    } catch (_) {
      return null;
    }
  }

  /// 全部任务列表（学习计划页）
  static Future<List<Map<String, dynamic>>> getAllTasks() async {
    final r = await _channel.invokeMethod('getAllTasks');
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 创建任务，返回新任务 id
  static Future<String> createTask({
    required String name,
    required String startDate,
    required String endDate,
    required String startTime,
    required String endTime,
    required List<int> weekDays,
  }) async {
    final r = await _channel.invokeMethod('createTask', {
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'week_days': weekDays,
    });
    return Map<String, dynamic>.from(r as Map)['id'] as String;
  }

  /// 保存一条打卡记录
  static Future<Map<String, dynamic>> addCheckin({
    required String taskId,
    required String taskName,
    required int durationSeconds,
    required String date,
  }) async {
    final r = await _channel.invokeMethod('addCheckin', {
      'task_id': taskId,
      'task_name': taskName,
      'duration_seconds': durationSeconds,
      'date': date,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// 全部打卡记录（倒序）
  static Future<List<Map<String, dynamic>>> getCheckinRecords() async {
    final r = await _channel.invokeMethod('getCheckinRecords');
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 某月打卡日历数据
  static Future<List<Map<String, dynamic>>> getCalendarData(int year, int month) async {
    final r = await _channel.invokeMethod('getCalendarData', {
      'year': year,
      'month': month,
    });
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 连续打卡天数
  static Future<int> getStreak() async {
    final r = await _channel.invokeMethod('getStreak');
    return (r as num).toInt();
  }

  /// 今日奖励状态 {total, finished, claimable, already_claimed}
  static Future<Map<String, dynamic>> getRewardStatus() async {
    final r = await _channel.invokeMethod('getRewardStatus');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 领取每日奖励 {success, exp_gained, pet_exp, pet_level, leveled_up}
  static Future<Map<String, dynamic>> claimDailyReward() async {
    final r = await _channel.invokeMethod('claimDailyReward');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 宠物信息
  static Future<Map<String, dynamic>> getPetInfo() async {
    final r = await _channel.invokeMethod('getPetInfo');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 更新宠物（仅传哪个改哪个）
  static Future<Map<String, dynamic>> updatePet({String? petType, String? petName}) async {
    final args = <String, dynamic>{};
    if (petType != null) args['pet_type'] = petType;
    if (petName != null) args['pet_name'] = petName;
    final r = await _channel.invokeMethod('updatePet', args);
    return Map<String, dynamic>.from(r as Map);
  }

  /// 综合资料
  static Future<Map<String, dynamic>> getProfile() async {
    final r = await _channel.invokeMethod('getProfile');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 更新用户资料（昵称 / 头像）
  static Future<Map<String, dynamic>> updateProfile({String? nickname, String? avatar}) async {
    final args = <String, dynamic>{};
    if (nickname != null) args['nickname'] = nickname;
    if (avatar != null) args['avatar'] = avatar;
    final r = await _channel.invokeMethod('updateProfile', args);
    return Map<String, dynamic>.from(r as Map);
  }

  /// 退出登录
  static Future<void> logout() async {
    await _channel.invokeMethod('logout');
  }

  /// 获取提醒设置
  static Future<Map<String, dynamic>> getReminderSettings() async {
    final r = await _channel.invokeMethod('getReminderSettings');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 保存提醒设置（仅传哪个改哪个）
  static Future<bool> saveReminderSettings({
    bool? remindEnabled,
    bool? inAppRemind,
    bool? bannerRemind,
    String? remindTime,
  }) async {
    final args = <String, dynamic>{};
    if (remindEnabled != null) args['remindEnabled'] = remindEnabled;
    if (inAppRemind != null) args['inAppRemind'] = inAppRemind;
    if (bannerRemind != null) args['bannerRemind'] = bannerRemind;
    if (remindTime != null) args['remindTime'] = remindTime;
    final r = await _channel.invokeMethod('saveReminderSettings', args);
    return Map<String, dynamic>.from(r as Map)['success'] as bool? ?? false;
  }

  /// 通知权限是否已授予（Android 13+ 的 POST_NOTIFICATIONS）
  static Future<bool> hasNotificationPermission() async {
    final r = await _channel.invokeMethod('hasNotificationPermission');
    return r == true;
  }

  /// 跳转系统应用通知设置页（引导用户手动开启通知）。返回是否成功拉起。
  static Future<bool> openNotificationSettings() async {
    final r = await _channel.invokeMethod('openNotificationSettings');
    return r == true;
  }

  /// 请求切换飞行模式。返回 {success, already, now_on, need_manual, message ...}
  /// 普通应用通常无法直接修改，会返回 need_manual=true 并自动跳转系统设置页
  static Future<Map<String, dynamic>> setAirplaneMode({required bool enable}) async {
    final r = await _channel.invokeMethod('setAirplaneMode', {'enable': enable});
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<bool> isAirplaneModeOn() async {
    final r = await _channel.invokeMethod('isAirplaneModeOn');
    return r == true;
  }

  /// 签到（不依赖任务完成）。返回 {success, exp_gained, pet_exp, pet_level, leveled_up, streak}
  static Future<Map<String, dynamic>> signIn() async {
    final r = await _channel.invokeMethod('signIn');
    return Map<String, dynamic>.from(r as Map);
  }

  /// 清除今日打卡（传 taskId 清单个，不传清全部）。返回 {success, removed}
  static Future<Map<String, dynamic>> clearTodayCheckins({String? taskId}) async {
    final args = <String, dynamic>{};
    if (taskId != null) args['task_id'] = taskId;
    final r = await _channel.invokeMethod('clearTodayCheckins', args);
    return Map<String, dynamic>.from(r as Map);
  }

  /// 当天日期字符串 yyyy-MM-dd
  static String todayYMD() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }
}
