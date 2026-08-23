import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';

class TaskCreatePage extends StatefulWidget {
  const TaskCreatePage({super.key});

  @override
  State<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends State<TaskCreatePage> {
  final TextEditingController _taskNameCtrl = TextEditingController();
  DateTime? _startDate;   // 任务开始日期
  DateTime? _endDate;     // 任务结束日期
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<bool> _weekSelect = [false, false, false, false, false, false, false];
  final List<String> _weekName = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];

  // 选择日期
  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now.add(const Duration(days: 30))),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5288E8)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // 选择时间
  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? res = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5288E8)),
          ),
          child: child!,
        );
      },
    );
    if (res != null) {
      setState(() {
        isStart ? _startTime = res : _endTime = res;
      });
    }
  }

  void _toggleWeekItem(int index) {
    setState(() => _weekSelect[index] = !_weekSelect[index]);
  }

  Future<void> _submitTask() async {
    final taskName = _taskNameCtrl.text.trim();
    // 周一=1 ... 周日=7
    final List<int> weekDays = [];
    for (int i = 0; i < 7; i++) {
      if (_weekSelect[i]) weekDays.add(i + 1);
    }

    if (taskName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入学习任务名称")));
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请选择任务起止日期")));
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请选择每日学习起止时段")));
      return;
    }
    if (weekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("至少选择一周中的一天执行")));
      return;
    }

    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String hm(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    try {
      await BackendService.createTask(
        name: taskName,
        startDate: ymd(_startDate!),
        endDate: ymd(_endDate!),
        startTime: hm(_startTime!),
        endTime: hm(_endTime!),
        weekDays: weekDays,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("学习任务创建成功")));
      Navigator.pop(context, true); // 返回 true 通知上层刷新
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? '创建失败')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败：$e')));
    }
  }

  @override
  void dispose() {
    _taskNameCtrl.dispose();
    super.dispose();
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF222222)),
      ),
    );
  }

  // 通用日期/时间选择卡片组件
  Widget buildSelectCard({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String? value,
    Color iconColor = const Color(0xFF5288E8),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7ED)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF909399))),
            const SizedBox(height: 6),
            Text(
              value ?? "未选择",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: value == null ? const Color(0xFF909399) : const Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text("新建学习任务", style: TextStyle(fontWeight: FontWeight.w500)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.4,
        foregroundColor: const Color(0xFF222222),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1.任务名称
            sectionTitle("任务名称"),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7ED)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _taskNameCtrl,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "例如：英语单词背诵、高数刷题练习",
                  hintStyle: TextStyle(color: Color(0xFF909399)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2.任务起止日期（左右双卡片）
            sectionTitle("任务执行日期区间"),
            Row(
              children: [
                Expanded(
                  child: buildSelectCard(
                    onTap: () => _pickDate(true),
                    icon: Icons.calendar_today_outlined,
                    title: "开始日期",
                    value: _startDate != null
                        ? "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}"
                        : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("～", style: TextStyle(fontSize: 20, color: Color(0xFFC0C4CC))),
                ),
                Expanded(
                  child: buildSelectCard(
                    onTap: () => _pickDate(false),
                    icon: Icons.event_outlined,
                    title: "结束日期",
                    value: _endDate != null
                        ? "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}"
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3.每日固定学习时段
            sectionTitle("每日学习时间段"),
            Row(
              children: [
                Expanded(
                  child: buildSelectCard(
                    onTap: () => _pickTime(true),
                    icon: Icons.access_time_outlined,
                    title: "开始时间",
                    value: _startTime?.format(context),
                    iconColor: const Color(0xFF6BB8A7),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text("～", style: TextStyle(fontSize: 20, color: Color(0xFFC0C4CC))),
                ),
                Expanded(
                  child: buildSelectCard(
                    onTap: () => _pickTime(false),
                    icon: Icons.timer_off_outlined,
                    title: "结束时间",
                    value: _endTime?.format(context),
                    iconColor: const Color(0xFF6BB8A7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4.每周重复选择
            sectionTitle("每周固定执行日期"),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7ED)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(7, (index) {
                  bool selected = _weekSelect[index];
                  return InkWell(
                    onTap: () => _toggleWeekItem(index),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 54,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFF0F4FF) : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: selected ? const Color(0xFF5288E8) : const Color(0xFFE4E7ED)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _weekName[index],
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? const Color(0xFF5288E8) : const Color(0xFF606266),
                          fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),

            // 底部创建按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x205288E8),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5288E8), Color(0xFF6498F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "确认创建任务",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}