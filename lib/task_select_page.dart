import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'study_timer_page.dart';
import 'task_create_page.dart';
import 'services/backend_service.dart';

class TaskSelectPage extends StatefulWidget {
  const TaskSelectPage({super.key});

  @override
  State<TaskSelectPage> createState() => _TaskSelectPageState();
}

class _TaskSelectPageState extends State<TaskSelectPage> {
  // 今日任务（来自后端）
  List<Map<String, dynamic>> _tasks = [];

  int? _selectedIndex;
  bool _dndMode = false;
  bool _loading = true;

  // 任务图标池，按 index 取模分配
  final List<IconData> taskIcons = [
    Icons.translate_outlined,
    Icons.calculate_outlined,
    Icons.menu_book_outlined,
    Icons.edit_note_outlined,
    Icons.science_outlined,
    Icons.history_edu_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final list = await BackendService.getTodayTasks();
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loading = false;
        // 若已选索引越界则重置
        if (_selectedIndex != null && _selectedIndex! >= _tasks.length) {
          _selectedIndex = null;
        }
      });
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        title: const Text('挑选今日学习任务'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3D4F6B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今天准备攻克哪一项？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D4F6B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '选中任务即可开启专注计时',
              style: TextStyle(fontSize: 13, color: Color(0xFF8B9DB8)),
            ),
            const SizedBox(height: 20),

            // 任务卡片列表 / 空状态
            _buildTaskArea(),

            const SizedBox(height: 24),
            // 美化后的勿扰模式卡片
            _buildDndSettingCard(),

            const SizedBox(height: 40),
            // 轻量化改版开始按钮
            _buildSoftStartButton(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskArea() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF87A8E4))),
      );
    }
    if (_tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                  if (mounted) {
                    setState(() => _loading = true);
                    _loadTasks();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF7BA7E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('去添加学习任务', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      );
    }
    return _buildNewTaskCardList();
  }

  Widget _buildNewTaskCardList() {
    return Column(
      children: List.generate(_tasks.length, (index) {
        final bool isSelect = _selectedIndex == index;
        final String name = _tasks[index]['name'] as String? ?? '';
        final bool finished = _tasks[index]['finished'] as bool? ?? false;
        final IconData icon = taskIcons[index % taskIcons.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedIndex = index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // 选中淡渐变底色，未选中纯白
                color: isSelect
                    ? const Color(0xFFE8EEFC)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelect
                      ? const Color(0xFF87A8E4)
                      : const Color(0xFFE2E9F5),
                  width: isSelect ? 1.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelect
                        ? const Color(0x1A7BA7E0)
                        : Colors.black12,
                    blurRadius: isSelect ? 8 : 3,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                children: [
                  // 左侧任务图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelect
                          ? const Color(0xFF87A8E4)
                          : const Color(0xFFF1F5FC),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelect ? Colors.white : const Color(0xFF7098D8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelect ? FontWeight.w600 : FontWeight.w400,
                        color: isSelect
                            ? const Color(0xFF3D4F6B)
                            : const Color(0xFF55647F),
                        decoration: finished ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                    ),
                  ),
                  if (finished)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle, size: 18, color: Color(0xFF63B895)),
                    ),
                  // 右侧选中对勾
                  if (isSelect)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF87A8E4),
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDndSettingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // 修复这里：Colors.black05 改为透明黑色0.05透明度
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5FC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.do_not_disturb_on_outlined,
              color: Color(0xFFA89BE2),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '专注勿扰模式',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF3D4F6B)),
                ),
                SizedBox(height: 3),
                Text(
                  '开启后学习期间锁定应用，无法退出直到结束打卡',
                  style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _dndMode,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF87A8E4).withOpacity(0.45),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDDE6F2),
            onChanged: (v) {
              setState(() => _dndMode = v);
              if (v) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('勿扰模式已开启：开始学习后将无法退出计时页面，直到结束打卡'),
                    backgroundColor: Color(0xFF639CE8),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSoftStartButton(BuildContext context) {
    final bool canClick = _selectedIndex != null && _selectedIndex! < _tasks.length;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: canClick
            ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => StudyTimerPage(
                taskId: _tasks[_selectedIndex!]['id'] as String,
                taskName: _tasks[_selectedIndex!]['name'] as String,
                dndMode: _dndMode,
              ),
            ),
          ).then((_) {
            if (mounted) {
              setState(() => _loading = true);
              _loadTasks();
            }
          });
        }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: canClick
                ? Colors.white.withOpacity(0.8)
                : const Color(0xFFE1E8F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: canClick ? const Color(0xFFC8D8F2) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: canClick
                ? const [
              BoxShadow(
                color: Color(0x1A7BA7E0),
                blurRadius: 12,
                offset: Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rocket_launch_outlined,
                color: canClick ? const Color(0xFF7098D8) : const Color(0xFFB0BCCD),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '开启专注计时',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: canClick
                      ? const Color(0xFF5279BB)
                      : const Color(0xFFA0AEC2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
