import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';

class RemindSettingPage extends StatefulWidget {
  const RemindSettingPage({super.key});

  @override
  State<RemindSettingPage> createState() => _RemindSettingPageState();
}

class _RemindSettingPageState extends State<RemindSettingPage> {
  bool _remindEnabled = true;
  bool _inAppRemind = true;
  bool _bannerRemind = false;
  TimeOfDay _remindTime = const TimeOfDay(hour: 8, minute: 0);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final s = await BackendService.getReminderSettings();
      if (!mounted) return;
      setState(() {
        _remindEnabled = s['remindEnabled'] as bool? ?? true;
        _inAppRemind = s['inAppRemind'] as bool? ?? true;
        _bannerRemind = s['bannerRemind'] as bool? ?? false;
        final rt = s['remindTime'] as String? ?? '08:00';
        final parts = rt.split(':');
        if (parts.length == 2) {
          _remindTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
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

  Future<void> _saveAll() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      final h = _remindTime.hour.toString().padLeft(2, '0');
      final m = _remindTime.minute.toString().padLeft(2, '0');
      await BackendService.saveReminderSettings(
        remindEnabled: _remindEnabled,
        inAppRemind: _inAppRemind,
        bannerRemind: _bannerRemind,
        remindTime: '$h:$m',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? '设置保存失败')));
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  /// 开启横幅提醒前检查通知权限：未授权则弹窗引导去系统设置，不开启。
  Future<void> _onBannerToggle(bool want) async {
    if (!want) {
      // 关闭直接保存
      setState(() => _bannerRemind = false);
      _saveAll();
      return;
    }
    // 开启：先检查通知权限
    bool granted = false;
    try {
      granted = await BackendService.hasNotificationPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    if (granted) {
      setState(() => _bannerRemind = true);
      _saveAll();
      return;
    }
    // 未授权：弹窗引导去系统设置，开关保持关闭
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('需要通知权限'),
        content: const Text('横幅提醒需要开启系统通知权限才能到点弹出横幅。\n是否前往系统设置开启「通知」权限？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去设置')),
        ],
      ),
    );
    if (!mounted) return;
    if (go == true) {
      try {
        await BackendService.openNotificationSettings();
      } catch (_) {}
    }
    if (!mounted) return;
    // 开关保持关闭，等用户从设置返回后再次手动开启
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在系统设置中开启通知后，再回来打开横幅提醒')),
    );
  }

  Future<void> _pickTime() async {
    final TimeOfDay? res = await showTimePicker(
      context: context,
      initialTime: _remindTime,
    );
    if (res != null && mounted) {
      setState(() => _remindTime = res);
      _saveAll();
    }
  }

  String _formatTime(TimeOfDay t) {
    String h = t.hour.toString().padLeft(2, '0');
    String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFEEF4FC),
        appBar: AppBar(
          title: const Text('提醒设置'),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          foregroundColor: const Color(0xFF3D4F6B),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF7BA7E0))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        title: const Text('提醒设置'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF3D4F6B),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7BA7E0))),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwitchCard(
              '开启提醒',
              '开启后将在每日设定时间提醒你学习',
              _remindEnabled,
              (v) {
                setState(() => _remindEnabled = v);
                _saveAll();
              },
            ),
            const SizedBox(height: 24),
            _buildGroupTitle('提醒方式'),
            _buildSwitchCard(
              'App内提醒',
              '在应用内弹出提醒消息',
              _inAppRemind,
              (v) {
                setState(() => _inAppRemind = v);
                _saveAll();
              },
              enabled: _remindEnabled,
            ),
            _buildSwitchCard(
              '手机通知横幅提醒',
              '开启后将在手机通知栏显示横幅（到每个任务的开始时间以及每日提醒时间）',
              _bannerRemind,
              (v) => _onBannerToggle(v),
              enabled: _remindEnabled,
            ),
            const SizedBox(height: 24),
            _buildGroupTitle('每日提醒时间'),
            _buildTimeCard(),
            if (_bannerRemind) ...[
              const SizedBox(height: 20),
              _buildBannerTip(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8B9DB8)),
      ),
    );
  }

  Widget _buildSwitchCard(String title, String desc, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? const Color(0xFF3D4F6B) : const Color(0xFFB8C5D6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Color(0xFF8B9DB8), fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF7BA7E0),
            activeTrackColor: const Color(0xFF7BA7E0).withValues(alpha: 0.4),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDDE6F2),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _remindEnabled ? _pickTime : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '提醒时间',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _remindEnabled ? const Color(0xFF3D4F6B) : const Color(0xFFB8C5D6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('每天定时提醒你开始学习', style: TextStyle(color: Color(0xFF8B9DB8), fontSize: 13)),
                ],
              ),
            ),
            Text(
              _formatTime(_remindTime),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _remindEnabled ? const Color(0xFF7BA7E0) : const Color(0xFFB8C5D6),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 14, color: _remindEnabled ? const Color(0xFFB8C5D6) : const Color(0xFFDDE6F2)),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerTip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x7FDCE9FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFF5A82C4)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '横幅提醒会在你设置的每日提醒时间和每个学习任务的开始时间弹出。请确保手机通知和定时提醒权限已开启。',
                style: TextStyle(fontSize: 12, color: Color(0xFF3D4F6B), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
