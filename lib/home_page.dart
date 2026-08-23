import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'task_select_page.dart';
import 'task_create_page.dart';
import 'services/backend_service.dart';
import 'main.dart' show petExpNotifier, petLevelNotifier;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _btnAnimCtrl;
  late AnimationController _bubbleCtrl1;
  late AnimationController _bubbleCtrl2;
  late Animation<double> animBubble1;
  late Animation<double> animBubble2;

  // 今日任务（来自后端）
  List<TaskItem> _todayTasks = [];
  // 今日奖励状态
  Map<String, dynamic>? _rewardStatus;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    // 按钮点击缩放动画
    _btnAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );

    // 气泡浮动动画1
    _bubbleCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    animBubble1 = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _bubbleCtrl1..repeat(reverse: true), curve: Curves.easeInOut),
    );

    // 气泡浮动动画2
    _bubbleCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    animBubble2 = Tween<double>(begin: 6, end: -6).animate(
      CurvedAnimation(parent: _bubbleCtrl2..repeat(reverse: true), curve: Curves.easeInOut),
    );

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        BackendService.getTodayTasks(),
        BackendService.getRewardStatus(),
      ]);
      if (!mounted) return;
      final tasks = results[0] as List<Map<String, dynamic>>;
      final reward = Map<String, dynamic>.from(results[1] as Map);
      setState(() {
        _todayTasks = tasks
            .map((e) => TaskItem(
                  title: e['name'] as String,
                  finished: e['finished'] as bool,
                  progress: (e['progress'] as num).toDouble(),
                ))
            .toList();
        _rewardStatus = reward;
      });
    } on PlatformException catch (_) {
      // 静默处理
    } catch (_) {}
  }

  Future<void> _claimReward() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final r = await BackendService.claimDailyReward();
      petExpNotifier.value = (r['pet_exp'] as num).toInt();
      petLevelNotifier.value = (r['pet_level'] as num).toInt();
      final leveledUp = r['leveled_up'] as bool;
      final exp = (r['exp_gained'] as num).toInt();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$exp 宠物经验${leveledUp ? '，宠物升级啦！🎉' : ''}')),
      );
      await _loadData();
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? '领取失败')));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  void dispose() {
    _btnAnimCtrl.dispose();
    _bubbleCtrl1.dispose();
    _bubbleCtrl2.dispose();
    super.dispose();
  }

  static const List<String> inspireTexts = [
    "慢慢蓄力，你想要的都在路上✨",
    "今日坚持打卡，离目标更近一步",
    "稳住节奏，认真的你格外耀眼",
    "不必内卷，顺着自己的节奏稳步前行",
    "默默沉淀，终会惊艳自己",
    "点滴积累，拼凑闪闪发光的自己",
    "坚持打卡，今天也很棒啦"
  ];

  @override
  Widget build(BuildContext context) {
    int finishCount = _todayTasks.where((t) => t.finished).length;
    double progress = _todayTasks.isEmpty ? 0 : finishCount / _todayTasks.length;

    return Container(
      color: const Color(0xFFF0F7FF),
      child: Stack(
        children: [
          _buildBubbleDecoration(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 90, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingArea(),
                const SizedBox(height: 28),
                _buildStartStudyBtn(context),
                const SizedBox(height: 28),
                _buildTotalProgressCard(progress, finishCount, _todayTasks.length),
                const SizedBox(height: 16),
                _buildRewardButton(),
                const SizedBox(height: 20),
                const Text(
                  "今日打卡清单",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF3D4F6B)),
                ),
                const SizedBox(height: 12),
                _buildTaskList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 页面底层全局背景气泡
  Widget _buildBubbleDecoration() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(top: 120, left: -30, child: _singleBubble(size: 90, opacity: 0.06)),
          Positioned(top: 320, right: -20, child: _singleBubble(size: 65, opacity: 0.05)),
          Positioned(top: 550, left: 20, child: _singleBubble(size: 50, opacity: 0.04)),
          Positioned(top: 720, right: 30, child: _singleBubble(size: 75, opacity: 0.05)),
          Positioned(bottom: 100, left: -10, child: _singleBubble(size: 80, opacity: 0.04)),
        ],
      ),
    );
  }

  Widget _singleBubble({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFA78BFA).withOpacity(opacity),
      ),
    );
  }

  Widget _buildGreetingArea() {
    final String randomInspire = inspireTexts[DateTime.now().millisecond % inspireTexts.length];
    final String greetContent = _getGreetText();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetContent,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3D4F6B)),
        ),
        const SizedBox(height: 4),
        Text(
          "${DateTime.now().month}月${DateTime.now().day}日｜认真学习的一天",
          style: TextStyle(color: const Color(0xFF8B9DB8), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEBFC).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            randomInspire,
            style: TextStyle(color: const Color(0xFF9B8FD9), fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _getGreetText() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "早呀～开启今日学习打卡";
    if (hour >= 12 && hour < 18) return "下午好，继续推进学习进度！";
    return "晚上啦，抓紧收尾今日任务～";
  }

  // 核心按钮：3d效果完美，张桂致大帅哥
  Widget _buildStartStudyBtn(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _btnAnimCtrl,
        child: GestureDetector(
          onTapDown: (_) {
            _btnAnimCtrl.reverse();
          },
          onTapUp: (_) {
            _btnAnimCtrl.forward();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const TaskSelectPage()),
            ).then((_) {
              if (mounted) _loadData();
            });
          },
          onTapCancel: () {
            _btnAnimCtrl.forward();
          },
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 修正：统一用 gradient 承载径向渐变
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 0.9,
                colors: [
                  Colors.white.withOpacity(0.4),
                  Color(0xFFD6E8FF).withOpacity(0.25),
                  Color(0xFFE0D9FB).withOpacity(0.15),
                ],
              ),
              // 仅单圈纤细气泡边框，消除双层圈
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.4,
              ),
              boxShadow: [
                // 外层悬浮投影，做出浮空立体感
                BoxShadow(
                  color: Color(0xFF8FB8E8).withOpacity(0.22),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                  spreadRadius: 3,
                ),
                // 用负值spreadRadius模拟内阴影，兼容所有Flutter版本，替代inset
                BoxShadow(
                  color: Colors.white.withOpacity(0.18),
                  blurRadius: 12,
                  offset: Offset(-5, -5),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 左上主反光圆点（气泡经典高光）
                Positioned(
                  top: 18,
                  left: 28,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                // 右上细长高光，强化球面弧度
                Positioned(
                  top: 24,
                  right: 32,
                  child: Transform.rotate(
                    angle: 0.4,
                    child: Container(
                      width: 26,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                // 中心文字
                Text(
                  "开始学习打卡",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F6B8A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTotalProgressCard(double progress, int finish, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("今日打卡进度", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF3D4F6B))),
              Text("已完成 $finish/$total 项", style: TextStyle(color: const Color(0xFF8B9DB8), fontSize: 13))
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE8EFF8),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF8FB8E8)),
            borderRadius: BorderRadius.circular(99),
            minHeight: 10,
          ),
          const SizedBox(height: 10),
          Text("整体完成率：${(progress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Color(0xFF6A9FD8), fontWeight: FontWeight.w500))
        ],
      ),
    );
  }

  /// 每日奖励按钮（三态）：
  /// 1) 没有今日任务 -> 完全不显示（用户要求"有今日的任务时才能显示"）
  /// 2) 有任务但未全部完成 -> 显示"去完成今日任务"，点击跳任务选择页
  /// 3) 有任务且全部完成且未领 -> 显示"领取今日奖励"按钮可点
  /// 4) 有任务但已领 -> 显示"今日奖励已领取"禁用
  Widget _buildRewardButton() {
    // 无今日任务时不显示（用任务列表直接判断，保证和"今日打卡清单"一致）
    if (_todayTasks.isEmpty) return const SizedBox.shrink();
    final rs = _rewardStatus;
    if (rs == null) return const SizedBox.shrink();
    final int total = (rs['total'] as num?)?.toInt() ?? _todayTasks.length;
    if (total == 0) return const SizedBox.shrink(); // 无任务不显示

    final int finished = (rs['finished'] as num?)?.toInt() ?? 0;
    final bool claimable = rs['claimable'] as bool? ?? false;
    final bool already = rs['already_claimed'] as bool? ?? false;

    String label;
    bool enabled;
    IconData icon;
    VoidCallback? action;
    // 样式：可点 vs 禁用
    bool claimMode = claimable; // "领取奖励"高亮样式
    bool goMode = !already && !claimable; // "去完成任务"的引导样式

    if (already) {
      label = '今日奖励已领取';
      enabled = false;
      icon = Icons.check_circle_rounded;
      action = null;
    } else if (claimable) {
      label = '领取今日奖励（+20 宠物经验）';
      enabled = true;
      icon = Icons.card_giftcard_rounded;
      action = _claiming ? null : _claimReward;
    } else {
      label = '去完成今日任务（$finished/$total）';
      enabled = true;
      icon = Icons.play_circle_outline_rounded;
      action = _claiming
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskSelectPage()),
              ).then((_) {
                if (mounted) _loadData();
              });
            };
    }

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: action,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: (claimMode && enabled)
                ? const LinearGradient(
                    colors: [Color(0xFF7BA7E0), Color(0xFF9B8FD9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: claimMode && enabled
                ? null
                : (goMode ? const Color(0xFFFEF7E5) : const Color(0xFFE8EFF8)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: goMode ? const Color(0x7FF3C97B) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: (claimMode && enabled)
                ? const [BoxShadow(color: Color(0x227BA7E0), blurRadius: 10, offset: Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: (claimMode && enabled)
                    ? Colors.white
                    : (already
                        ? const Color(0xFFB8C5D6)
                        : (goMode ? const Color(0xFFD2A94F) : const Color(0xFFB8C5D6))),
              ),
              const SizedBox(width: 8),
              Text(
                _claiming && claimMode ? '领取中...' : label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: (claimMode && enabled)
                      ? Colors.white
                      : (already
                          ? const Color(0xFF8B9DB8)
                          : (goMode ? const Color(0xFFA87F1F) : const Color(0xFF8B9DB8))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    if (_todayTasks.isEmpty) {
      return _buildEmptyTask();
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: _todayTasks.map((item) => _buildTaskItem(item)).toList()),
    );
  }

  // 空状态：引导去添加学习任务
  Widget _buildEmptyTask() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 46, color: Color(0xFFB8C5D6)),
          const SizedBox(height: 12),
          const Text('今日暂无学习任务', style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 14)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskCreatePage()),
              ).then((_) {
                if (mounted) _loadData();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF7BA7E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '去添加学习任务',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskItem item) {
    int percent = (item.progress * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 24,
              height: 24,
              decoration: item.finished
                  ? BoxDecoration(
                color: const Color(0xFF8FB8E8),
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x188FB8E8), blurRadius: 4, offset: Offset(0, 2))],
              )
                  : BoxDecoration(border: Border.all(color: const Color(0xFFB8C5D6), width: 1.6), shape: BoxShape.circle),
              child: item.finished ? const Icon(Icons.check_rounded, color: Colors.white, size: 15, weight: 4) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    decoration: item.finished ? TextDecoration.lineThrough : TextDecoration.none,
                    color: item.finished ? const Color(0xFFB8C5D6) : const Color(0xFF3D4F6B),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          backgroundColor: const Color(0xFFE8EFF8),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFB8A8E2)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 38, child: Text("$percent%", textAlign: TextAlign.right, style: TextStyle(color: const Color(0xFF8B9DB8), fontSize: 12))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TaskItem {
  final String title;
  final bool finished;
  final double progress;

  const TaskItem({required this.title, required this.finished, required this.progress});
}
