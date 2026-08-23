import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final list = await BackendService.getAllTasks();
      if (!mounted) return;
      setState(() {
        _plans = list;
        _loading = false;
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
        title: const Text('我的学习计划'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF3D4F6B),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF7BA7E0),
        onRefresh: _loadPlans,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7BA7E0)));
    }
    if (_plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: const [
                Icon(Icons.event_note_outlined, size: 48, color: Color(0xFFB8C5D6)),
                SizedBox(height: 12),
                Text('暂无学习计划', style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 14)),
                SizedBox(height: 6),
                Text('去「我的-添加学习任务」创建吧', style: TextStyle(color: Color(0xFFB8C5D6), fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        children: _plans.map((plan) => _buildPlanCard(plan)).toList(),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final double progressValue = (plan['progress'] as num?)?.toDouble() ?? 0.0;
    final String name = plan['name'] as String? ?? '';
    final String startDate = plan['start_date'] as String? ?? '';
    final String endDate = plan['end_date'] as String? ?? '';
    final String startTime = plan['start_time'] as String? ?? '';
    final String endTime = plan['end_time'] as String? ?? '';
    final String progressText = '${(progressValue * 100).toStringAsFixed(0)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 进度百分比
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D4F6B),
                  ),
                ),
              ),
              Text(
                progressText,
                style: const TextStyle(
                  color: Color(0xFF7BA7E0),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 任务开始日期 ~ 截止日期
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 14,
                color: Color(0xFF8B9DB8),
              ),
              const SizedBox(width: 6),
              Text(
                '任务时间：$startDate ～ $endDate',
                style: const TextStyle(
                  color: Color(0xFF8B9DB8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 每日固定学习时段
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Color(0xFF9B8FD9),
              ),
              const SizedBox(width: 6),
              Text(
                '每日时段：$startTime - $endTime',
                style: const TextStyle(
                  color: Color(0xFF9B8FD9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: const Color(0xFFE8EFF8),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7BA7E0)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
