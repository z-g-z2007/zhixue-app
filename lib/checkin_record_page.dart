import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';

class CheckinRecordPage extends StatefulWidget {
  const CheckinRecordPage({super.key});

  @override
  State<CheckinRecordPage> createState() => _CheckinRecordPageState();
}

class _CheckinRecordPageState extends State<CheckinRecordPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final list = await BackendService.getCheckinRecords();
      if (!mounted) return;
      setState(() {
        _records = list;
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

  // 秒 → 友好时长显示
  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '0分钟';
    int m = (seconds / 60).ceil();
    if (m < 1) m = 1;
    if (m >= 60) {
      int h = m ~/ 60;
      int rest = m % 60;
      return rest == 0 ? '$h小时' : '$h小时$rest分钟';
    }
    return '$m分钟';
  }

  // 计划时段标签（关联任务的 start_time/end_time）
  Widget _buildPlanTime(Map<String, dynamic> record) {
    final st = record['start_time'] as String?;
    final et = record['end_time'] as String?;
    if (st == null || st.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_outlined, size: 11, color: Color(0xFF9B8FD9)),
          const SizedBox(width: 3),
          Text(
            '计划时段 $st-$et',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B8FD9)),
          ),
        ],
      ),
    );
  }

  // yyyy-MM-dd → MM-dd
  String _shortDate(String date) {
    if (date.length >= 10) return date.substring(5, 10);
    return date;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text(
          '打卡完成记录',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.2,
        foregroundColor: const Color(0xFF4A5A75),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF6A8FBD),
        onRefresh: _loadRecords,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6A8FBD)));
    }
    if (_records.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: const [
                Icon(Icons.history_toggle_off, size: 48, color: Color(0xFFB8C5D6)),
                SizedBox(height: 12),
                Text('暂无打卡记录', style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 14)),
                SizedBox(height: 6),
                Text('完成一次专注学习后这里会有记录', style: TextStyle(color: Color(0xFFB8C5D6), fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '历史打卡明细',
              style: TextStyle(fontSize: 14, color: Color(0xFF8693AB)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x086896D0),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _records.map((record) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _shortDate(record['date'] as String? ?? ''),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF526890),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['task_name'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF3E4C66),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _fmtDuration((record['duration_seconds'] as num?)?.toInt() ?? 0),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7C8BA3),
                              ),
                            ),
                            _buildPlanTime(record),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '已完成',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A8FBD),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
