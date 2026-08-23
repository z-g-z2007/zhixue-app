import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'task_create_page.dart';
import 'study_plan_page.dart';
import 'checkin_record_page.dart';
import 'supervise_setting_page.dart' show RemindSettingPage;
import 'account_page.dart';
import 'main.dart' show userNicknameNotifier, userAccountIdNotifier, selectedPetNotifier, streakNotifier, userAvatarNotifier;
import 'services/backend_service.dart';

// 新增个人资料页面（点击头部跳转）
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("个人资料"), centerTitle: true),
      body: const Center(child: Text("头像、昵称、账号信息编辑页面")),
    );
  }
}

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  @override
  void initState() {
    super.initState();
    userNicknameNotifier.addListener(_onUserChanged);
    userAccountIdNotifier.addListener(_onUserChanged);
    selectedPetNotifier.addListener(_onUserChanged);
    streakNotifier.addListener(_onUserChanged);
    userAvatarNotifier.addListener(_onUserChanged);
    _loadMonth(_currentMonth);
  }

  @override
  void dispose() {
    userNicknameNotifier.removeListener(_onUserChanged);
    userAccountIdNotifier.removeListener(_onUserChanged);
    selectedPetNotifier.removeListener(_onUserChanged);
    streakNotifier.removeListener(_onUserChanged);
    userAvatarNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildAvatar() {
    final String avatar = userAvatarNotifier.value;
    final bool isFile = avatar.startsWith('/') || avatar.contains('\\') || avatar.startsWith('file:');
    if (isFile) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: const Color(0xFFE1ECFC),
        child: ClipOval(
          child: Image.file(
            File(avatar),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.person, size: 38, color: const Color(0xFF7BA7E0)),
          ),
        ),
      );
    }
    // 预设 key 兜底
    const Map<String, IconData> iconMap = {
      'student': Icons.school,
      'cat': Icons.pets_outlined,
      'dog': Icons.cruelty_free_outlined,
      'star': Icons.star_rounded,
      'book': Icons.menu_book_outlined,
      'palette': Icons.palette_outlined,
    };
    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFFE1ECFC),
      child: Icon(iconMap[avatar] ?? Icons.person, size: 38, color: const Color(0xFF7BA7E0)),
    );
  }

  final List<String> _aiRandomText = const [
    "你可以向我咨询学习规划、知识点答疑、拆解每日学习任务，我会根据你的计划给出适配的学习建议。",
    "结合你已制定的学习任务，合理拆分学习时段，劳逸结合能够有效提升专注度与学习吸收效率。",
    "遇到难以攻克的学习内容时，可以把问题详细发给我，我帮你梳理解题思路、总结核心考点。",
    "长期坚持规律打卡很关键，我可以帮你复盘近期学习完成情况，优化后续的学习安排。",
    "不管是背诵规划、刷题安排还是时间管理，都可以直接提问，我会给出针对性的学习方案。"
  ];

  // 日历数据：key = yyyy-MM-dd，来自后端
  Map<String, Map<String, dynamic>> _calendarMap = {};

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth(DateTime m) async {
    try {
      final list = await BackendService.getCalendarData(m.year, m.month);
      if (!mounted) return;
      final map = <String, Map<String, dynamic>>{};
      for (final e in list) {
        map[e['date'] as String] = Map<String, dynamic>.from(e);
      }
      setState(() => _calendarMap = map);
    } on PlatformException catch (_) {
    } catch (_) {}
  }

  List<DateTime> _getCurrentMonthDays() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    List<DateTime> dayList = [];
    for (int i = 0; i < lastDay.day; i++) {
      dayList.add(firstDay.add(Duration(days: i)));
    }
    return dayList;
  }

  Map<String, dynamic>? _getCurrentDayRecord() {
    return _calendarMap[_ymd(_selectedDate)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 50, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部独立卡片，整体可点击 + 浅蓝底色
            _buildUserInfoHeader(context),
            const SizedBox(height: 20),
            _buildEntryBtn(
              context,
              icon: Icons.edit_note_outlined,
              title: '添加学习任务',
              desc: '制定新的学习计划与时间安排',
              page: const TaskCreatePage(),
              mainColor: const Color(0xFF7BA7E0),
            ),
            const SizedBox(height: 12),
            _buildEntryBtn(
              context,
              icon: Icons.calendar_month_outlined,
              title: '我的学习计划',
              desc: '查看与管理所有学习计划',
              page: const StudyPlanPage(),
              mainColor: const Color(0xFF9B8FD9),
            ),
            const SizedBox(height: 12),
            _buildEntryBtn(
              context,
              icon: Icons.check_circle_outline,
              title: '打卡完成记录',
              desc: '查看历史打卡与完成情况',
              page: const CheckinRecordPage(),
              mainColor: const Color(0xFF63B895),
            ),
            const SizedBox(height: 12),
            _buildEntryBtn(
              context,
              icon: Icons.notifications_outlined,
              title: '提醒设置',
              desc: '配置每日学习提醒方式与时间',
              page: const RemindSettingPage(),
              mainColor: const Color(0xFFE57373),
            ),
            const SizedBox(height: 24),
            _buildAiSection(),
            const SizedBox(height: 24),
            _buildCustomStyleCalendar(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 修改后的头部：整区域点击跳转 + 浅冰蓝背景，其余布局完全沿用你原来结构
  Widget _buildUserInfoHeader(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 点击整张卡片跳转账号信息页
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          // 极浅冰蓝，无紫色、颜色柔和不刺眼
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userNicknameNotifier.value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3B52),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '账号：${userAccountIdNotifier.value}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF70829C)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFFA1B2CC),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryBtn(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String desc,
        required Widget page,
        required Color mainColor,
      }) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => page));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: mainColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3D4F6B))),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(color: Color(0xFF8B9DB8), fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFB8C5D6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    final String aiTip = _aiRandomText[DateTime.now().millisecond % _aiRandomText.length];
    const double borderWidth = 1.2;
    const double radius = 18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7BA7E0), Color(0xFF9B8FD9)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "至学AI 学习助手",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D4F6B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7BA7E0), Color(0xFF9B8FD9)],
            ),
            borderRadius: BorderRadius.all(Radius.circular(radius)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A7BA7E0),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(radius - borderWidth)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI小提示",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7BA7E0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  aiTip,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFF556480),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: const Text(
                    "后续可开启对话咨询学习问题✨",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B8FD9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomStyleCalendar() {
    final List<DateTime> monthDays = _getCurrentMonthDays();
    final dayRecord = _getCurrentDayRecord();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF7BA7E0)),
            SizedBox(width: 8),
            Text(
              "学习打卡日历",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3D4F6B)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      });
                      _loadMonth(_currentMonth);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF8B9DB8)),
                    ),
                  ),
                  Text(
                    "${_currentMonth.year}年${_currentMonth.month}月",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF3D4F6B)),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      });
                      _loadMonth(_currentMonth);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF8B9DB8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ["一", "二", "三", "四", "五", "六", "日"]
                    .map((week) => Text(
                  week,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9AA7BC)),
                ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 7,
                physics: const NeverScrollableScrollPhysics(),
                children: monthDays.map((day) {
                  bool isSelect = _isSameDay(day, _selectedDate);
                  bool isToday = _isSameDay(day, DateTime.now());
                  bool hasStudyRecord = _calendarMap.containsKey(_ymd(day));

                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () {
                      setState(() {
                        _selectedDate = day;
                      });
                    },
                    child: SizedBox(
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelect
                                  ? const Color(0xFF7BA7E0)
                                  : isToday
                                  ? const Color(0xFF7BA7E0).withOpacity(0.13)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "${day.day}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday ? FontWeight.w500 : FontWeight.normal,
                                  color: isSelect ? Colors.white : const Color(0xFF3D4F6B),
                                ),
                              ),
                            ),
                          ),
                          if (hasStudyRecord)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF9B8FD9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFE8EFF8)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: dayRecord != null
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_selectedDate.month}月${_selectedDate.day}日学习数据",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF3D4F6B)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFC),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        "累计学习 ${dayRecord["study_minute"]} 分钟",
                        style: const TextStyle(color: Color(0xFF7BA7E0), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text("当日已完成任务", style: TextStyle(fontSize: 14, color: Color(0xFF556480))),
                    const SizedBox(height: 8),
                    ...List.generate(
                      dayRecord["tasks"].length,
                          (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF63B895)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dayRecord["tasks"][index],
                                style: const TextStyle(fontSize: 13, color: Color(0xFF556480)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      "该日期暂无学习打卡记录，快去完成学习打卡吧",
                      style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}