import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';

class StudyTimerPage extends StatefulWidget {
  final String taskId;
  final String taskName;
  final bool dndMode;

  const StudyTimerPage({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.dndMode,
  });

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  int _seconds = 0; // 本次计时器的秒数
  bool _running = false;
  Timer? _timer;
  bool _finished = false; // 是否已结束打卡（结束后允许退出）

  // 今日该任务的累计实际秒数（进入时加载）
  int _accumulatedSeconds = 0;
  // 计划总秒数（start_time -> end_time）
  int _plannedSeconds = 0;
  String _plannedLabel = ''; // e.g. 09:00-10:00
  // 加载完成
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await BackendService.getTodayTaskById(widget.taskId);
      if (!mounted) return;
      final int planned = (detail?['planned_seconds'] as num?)?.toInt() ?? 0;
      final int acc = (detail?['accumulated_seconds'] as num?)?.toInt() ?? 0;
      final st = detail?['start_time'] as String? ?? '';
      final et = detail?['end_time'] as String? ?? '';
      setState(() {
        _plannedSeconds = planned > 0 ? planned : 60;
        _accumulatedSeconds = acc;
        _plannedLabel = '$st-$et';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _plannedSeconds = 60;
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    setState(() => _running = true);
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  Future<void> _finishTimer() async {
    _timer?.cancel();
    setState(() {
      _running = false;
      _finished = true; // 结束打卡后允许退出
    });
    if (_seconds <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本次计时不足1秒，暂未记录')),
        );
      }
      Navigator.pop(context, true);
      return;
    }
    bool justReached = false;
    try {
      final before = _accumulatedSeconds;
      final after = before + _seconds;
      justReached = before < _plannedSeconds && after >= _plannedSeconds;
      await BackendService.addCheckin(
        taskId: widget.taskId,
        taskName: widget.taskName,
        durationSeconds: _seconds,
        date: BackendService.todayYMD(),
      );
    } catch (_) {
      // 保存失败不阻塞用户
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text(justReached ? '🎉 任务完成，打卡成功' : '📝 已记录本次学习'),
        content: Text(
            '本次学习时长：${_formatTime(_seconds)}\n专注任务：${widget.taskName}\n计划时段：${_plannedLabel}\n今日累计：${_formatTime(_accumulatedSeconds + _seconds)} / ${_formatTime(_plannedSeconds)}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); // 返回 true 通知上层刷新
            },
            child: const Text('收下成果', style: TextStyle(color: Color(0xFF87A8E4))),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    String hh = h.toString().padLeft(2, '0');
    String mm = m.toString().padLeft(2, '0');
    String ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalDone = _accumulatedSeconds + _seconds;
    final double ratio = _plannedSeconds == 0
        ? 0
        : (totalDone / _plannedSeconds).clamp(0.0, 1.0);
    final bool reached = totalDone >= _plannedSeconds;
    // 勿扰模式下，未结束打卡时不允许退出
    final bool canPop = !widget.dndMode || _finished;

    return PopScope(
      canPop: canPop,
      child: Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        title: const Text('专注自习计时'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF425270),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _loading
              ? const CircularProgressIndicator(color: Color(0xFF87A8E4))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 任务标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EDFB),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmarks_outlined, size: 15, color: Color(0xFF87A8E4)),
                          const SizedBox(width: 6),
                          Text(
                            widget.taskName,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF526899), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (widget.dndMode) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.do_not_disturb_on_outlined, size: 14, color: Color(0xFFA89BE2)),
                          SizedBox(width: 4),
                          Text('勿扰模式已锁定', style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 13)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '计划 $_plannedLabel  共 ${_formatTime(_plannedSeconds)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8B9DB8)),
                    ),
                    const SizedBox(height: 20),
                    // 环形进度：(累计+本次)/计划
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: const Color(0xFFE3ECF9),
                            valueColor: AlwaysStoppedAnimation(
                              reached ? const Color(0xFF69C77D) : const Color(0xFF87A8E4),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_seconds),
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3D4F6B),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _running ? '正在专注计时中' : (reached ? '已达到计划时长 ✨' : '计时已暂停'),
                              style: TextStyle(
                                color: reached ? const Color(0xFF4BA96B) : const Color(0xFF8B9DB8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FD),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '今日 ${_formatTime(totalDone)} / ${_formatTime(_plannedSeconds)}  (${(ratio * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF566B8C),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCtrlBtn(
                          icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          label: _running ? '暂停' : '开始',
                          onTap: _running ? _pauseTimer : _startTimer,
                        ),
                        const SizedBox(width: 28),
                        _buildCtrlBtn(
                          icon: Icons.stop_circle_outlined,
                          label: '结束打卡',
                          onTap: _finishTimer,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
      ),
    );
  }

  Widget _buildCtrlBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8E4F8), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x187BA7E0), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Icon(
              icon,
              size: 28,
              color: const Color(0xFF7098D8),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF667899), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
