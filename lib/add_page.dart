import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'main.dart' show selectedPetNotifier, petNameNotifier, petExpNotifier, petLevelNotifier, streakNotifier;
import 'services/backend_service.dart';

class AddPage extends StatefulWidget {
  final ValueListenable<int>? activeIndexNotifier;

  const AddPage({
    super.key,
    this.activeIndexNotifier,
  });

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> with WidgetsBindingObserver {
  VideoPlayerController? _idleController;
  VideoPlayerController? _eatController;
  bool _isInitialized = false;
  bool _isEating = false;
  bool _wasPlayingBeforePause = false;

  // 当前宠物类型：'cat' 或 'dog'
  String _petType = 'cat';
  // 宠物昵称
  String _petName = '小猫咪';

  int petLevel = 1;
  int petExp = 0;
  int expNeedForNextLv = 100;
  int feedCount = 1;

  bool todaySigned = false;
  int continueSignDays = 0;
  // 从后端 getRewardStatus 动态读取
  bool studyTaskDone = false;
  // 标记今日是否已经领取学习任务经验
  bool _hasGainStudyExp = false;
  // 今日任务总数（0 表示无任务，此时不可领取）
  int _todayTaskTotal = 0;

  // 玻璃气泡感绿色
  static const Color _glassGreen = Color(0xFFA7E9AF);
  static const Color _glassGreenDark = Color(0xFF69C77D);
  static const Color _glassGreenBg = Color(0xFFF4FFEE);
  static const Color _glassShadow = Color(0x1A69C77D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _petType = selectedPetNotifier.value == '小狗' ? 'dog' : 'cat';
    _petName = petNameNotifier.value;
    petExp = petExpNotifier.value;
    petLevel = petLevelNotifier.value;
    continueSignDays = streakNotifier.value;
    // todaySigned 由 _loadBackendData 根据 already_claimed 设置，这里先默认 false
    todaySigned = false;
    _initVideos();
    widget.activeIndexNotifier?.addListener(_onActiveChanged);
    selectedPetNotifier.addListener(_onPetChanged);
    petNameNotifier.addListener(_onPetNameChanged);
    _loadBackendData();
  }

  /// 从后端加载奖励状态（任务完成情况 + 是否已领取）
  Future<void> _loadBackendData() async {
    try {
      final rs = await BackendService.getRewardStatus();
      if (!mounted) return;
      final int total = (rs['total'] as num?)?.toInt() ?? 0;
      final int finished = (rs['finished'] as num?)?.toInt() ?? 0;
      final bool already = rs['already_claimed'] as bool? ?? false;
      final bool signedIn = rs['signed_in'] as bool? ?? false;
      setState(() {
        _todayTaskTotal = total;
        // 有任务且全部完成才算 studyTaskDone；无任务时为 false（不可领取）
        studyTaskDone = total > 0 && finished >= total;
        _hasGainStudyExp = already;
        // 签到状态 = 今日是否已签到（独立于任务完成）
        todaySigned = signedIn;
      });
    } on PlatformException catch (_) {
      // 静默
    } catch (_) {}
  }

  void _onPetChanged() {
    final newType = selectedPetNotifier.value == '小狗' ? 'dog' : 'cat';
    if (newType == _petType) return;
    _petType = newType;
    _reloadVideos();
  }

  void _onPetNameChanged() {
    setState(() => _petName = petNameNotifier.value);
  }

  Future<void> _reloadVideos() async {
    // 释放旧控制器
    _eatController?.removeListener(_onEatPositionChanged);
    _idleController?.dispose();
    _eatController?.dispose();
    _idleController = null;
    _eatController = null;

    if (mounted) setState(() => _isInitialized = false);

    _idleController = VideoPlayerController.asset('assets/videos/idle-$_petType.mp4');
    _eatController = VideoPlayerController.asset('assets/videos/eat-$_petType.mp4');

    await Future.wait([
      _idleController!.initialize(),
      _eatController!.initialize(),
    ]);

    if (!mounted) return;
    _idleController!.setLooping(true);
    _idleController!.setVolume(0.0);
    _eatController!.setLooping(false);
    _eatController!.setVolume(0.0);
    _eatController!.addListener(_onEatPositionChanged);
    _isEating = false;
    setState(() => _isInitialized = true);
    if (widget.activeIndexNotifier?.value == 1) {
      _idleController!.play();
    }
  }

  void _onActiveChanged() {
    if (!_isInitialized) return;
    final isActive = widget.activeIndexNotifier?.value == 1;
    isActive ? _resumePlayback() : _pauseAll();
    // 重新进入本页时刷新后端奖励状态（打卡后状态会变）
    if (isActive) _loadBackendData();
  }

  void _initVideos() {
    _idleController = VideoPlayerController.asset('assets/videos/idle-$_petType.mp4');
    _eatController = VideoPlayerController.asset('assets/videos/eat-$_petType.mp4');

    Future.wait([
      _idleController!.initialize(),
      _eatController!.initialize(),
    ]).then((_) {
      if (!mounted) return;
      _idleController!.setLooping(true);
      _idleController!.setVolume(0.0);
      _eatController!.setLooping(false);
      _eatController!.setVolume(0.0);
      _eatController!.addListener(_onEatPositionChanged);
      setState(() => _isInitialized = true);
      if (widget.activeIndexNotifier?.value == 1) {
        _idleController!.play();
      }
    });
  }

  void _onEatPositionChanged() {
    final c = _eatController;
    if (c == null || !c.value.isInitialized) return;
    if (!c.value.isPlaying && c.value.position >= c.value.duration) {
      _switchToIdle();
    }
  }

  void _switchToIdle() {
    _eatController!.seekTo(Duration.zero);
    setState(() => _isEating = false);
    if (widget.activeIndexNotifier?.value == 1) {
      _idleController!.play();
    }
  }

  void _resumePlayback() {
    _isEating ? _eatController?.play() : _idleController?.play();
  }

  void _pauseAll() {
    _idleController?.pause();
    _eatController?.pause();
  }

  Future<void> _signIn() async {
    if (todaySigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("今日已经签到过啦，明天再来～"), backgroundColor: Colors.orange),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("每日签到"),
        content: Text("确定进行今日签到吗？\n连续打卡：$continueSignDays 天"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("确认签到"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 签到独立于任务完成，走后端 signIn
    try {
      final r = await BackendService.signIn();
      final int exp = (r['exp_gained'] as num?)?.toInt() ?? 0;
      final int newExp = (r['pet_exp'] as num?)?.toInt() ?? petExp;
      final int newLevel = (r['pet_level'] as num?)?.toInt() ?? petLevel;
      final int newStreak = (r['streak'] as num?)?.toInt() ?? continueSignDays + 1;
      if (!mounted) return;
      setState(() {
        todaySigned = true;
        continueSignDays = newStreak;
        feedCount += 1;
        petExp = newExp;
        petLevel = newLevel;
        if (continueSignDays == 2) feedCount += 1;
        if (continueSignDays == 3) feedCount += 2;
        if (continueSignDays >= 5) feedCount += 2;
      });
      petExpNotifier.value = newExp;
      petLevelNotifier.value = newLevel;
      streakNotifier.value = newStreak;
      if (!mounted) return;
      _showSignInResult(true, '签到成功', '+$exp 经验，连续打卡 $newStreak 天');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSignInResult(false, '签到失败', e.message ?? '请稍后再试');
    } catch (_) {
      if (!mounted) return;
      _showSignInResult(false, '签到失败', '请稍后再试');
    }
  }

  /// 签到结果弹窗（用弹窗而非 SnackBar，避免被底部导航栏遮挡）
  void _showSignInResult(bool success, String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? const Color(0xFF69C77D) : Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF304870))),
            const SizedBox(height: 8),
            Text(detail, style: const TextStyle(fontSize: 14, color: Color(0xFF7088AA)), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7BA7E0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('好的', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// 升级逻辑：每升一级所需经验翻倍
  void _checkLevelUp() {
    while (petExp >= expNeedForNextLv) {
      petExp -= expNeedForNextLv;
      petLevel++;
      expNeedForNextLv *= 2;
    }
  }

  void _feedPet() {
    if (feedCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("暂无喂食次数，先完成签到领取次数吧"), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      feedCount--;
      petExp += 30;
      _checkLevelUp();
    });
    if (_isInitialized && !_isEating) {
      _idleController?.pause();
      _eatController!.seekTo(Duration.zero);
      _eatController!.play();
      setState(() => _isEating = true);
    }
    // 已移除投喂成功SnackBar
  }

  /// 领取学习任务经验，一天仅可领取一次（走后端 claimDailyReward）
  Future<void> _gainStudyTaskExp() async {
    if (_todayTaskTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("今日暂无学习任务，无法领取奖励"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!studyTaskDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("还未完成今日学习任务，暂时无法领取"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_hasGainStudyExp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("今日学习任务经验已经领取过了"), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final r = await BackendService.claimDailyReward();
      final int exp = (r['exp_gained'] as num?)?.toInt() ?? 0;
      final bool leveledUp = r['leveled_up'] as bool? ?? false;
      final int newExp = (r['pet_exp'] as num?)?.toInt() ?? petExp;
      final int newLevel = (r['pet_level'] as num?)?.toInt() ?? petLevel;
      if (!mounted) return;
      setState(() {
        petExp = newExp;
        petLevel = newLevel;
        _hasGainStudyExp = true;
      });
      petExpNotifier.value = newExp;
      petLevelNotifier.value = newLevel;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("+$exp 宠物经验${leveledUp ? '，宠物升级啦！🎉' : ''}")),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '领取失败')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('领取失败')),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if ((_idleController?.value.isPlaying ?? false) || (_eatController?.value.isPlaying ?? false)) {
          _wasPlayingBeforePause = true;
        }
        _pauseAll();
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause && widget.activeIndexNotifier?.value == 1) {
          _resumePlayback();
        }
        _wasPlayingBeforePause = false;
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    selectedPetNotifier.removeListener(_onPetChanged);
    petNameNotifier.removeListener(_onPetNameChanged);
    widget.activeIndexNotifier?.removeListener(_onActiveChanged);
    _eatController?.removeListener(_onEatPositionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _idleController?.dispose();
    _eatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildPetSection(),
              _buildGradientTransition(),
              const SizedBox(height: 8),
              buildFeedCard(),
              const SizedBox(height: 16),
              buildSignCard(),
              const SizedBox(height: 16),
              buildStudyTaskCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "$_petName Lv.$petLevel",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF365889)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: petExp / expNeedForNextLv,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: const Color(0xFFE4ECF7),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7BA7E0)),
                  minHeight: 9,
                ),
                const SizedBox(height: 4),
                Text(
                  "经验 $petExp / $expNeedForNextLv",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF607899)),
                ),
              ],
            ),
          ),
          // 新增：美化后的规则说明行
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              "Lv5解锁宠物新动作",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Color(0xFF5272A0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildVideoPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientTransition() {
    return Container(
      width: double.infinity,
      height: 28,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFF5F9FF),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized || _idleController == null || _eatController == null) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(Color(0xFF7BA7E0)),
          ),
        ),
      );
    }

    final activeController = _isEating ? _eatController! : _idleController!;
    final Size videoSize = activeController.value.size;
    final double screenW = MediaQuery.of(context).size.width;

    const double cropTop = 150.0;
    const double cropBottom = 250.0;
    const double cropSide = 20.0;
    final double croppedW = videoSize.width - cropSide * 2;
    final double croppedH = videoSize.height - cropTop - cropBottom;
    final double displayW = screenW * 0.75;

    return Center(
      child: SizedBox(
        width: displayW,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.white,
            child: AspectRatio(
              aspectRatio: croppedW / croppedH,
              child: FittedBox(
                fit: BoxFit.fill,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: croppedW,
                  height: croppedH,
                  child: OverflowBox(
                    alignment: Alignment(0, (cropBottom - cropTop) / (cropTop + cropBottom)),
                    minWidth: videoSize.width,
                    minHeight: videoSize.height,
                    maxWidth: videoSize.width,
                    maxHeight: videoSize.height,
                    child: VideoPlayer(activeController),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFeedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x1272A9F7), blurRadius: 12, offset: Offset(0, 5)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 4)],
                ),
                child: const Icon(Icons.pets, color: Color(0xFF5A94E8), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "投喂$_petName",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D4A78)),
                    ),
                    Text(
                      "当前可用喂食次数：$feedCount 次（投喂+30经验）",
                      style: const TextStyle(fontSize: 13, color: Color(0xFF647FA8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.85),
                    const Color(0xFFE1EDFF).withOpacity(0.75),
                  ],
                ),
                boxShadow: [
                  const BoxShadow(color: Color(0x1A5A94E8), blurRadius: 8, offset: Offset(0, 3)),
                  BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 2, offset: const Offset(0, -2)),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _feedPet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pets, color: Color(0xFF4A86DD), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "投喂$_petName",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF3B6BBF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSignCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: todaySigned ? _glassGreenBg : const Color(0xFF7BA7E0).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              todaySigned ? Icons.check_circle : Icons.calendar_today_outlined,
              color: todaySigned ? _glassGreenDark : const Color(0xFF7BA7E0),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("每日签到打卡", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF304870))),
                Text(
                  todaySigned ? "已签到，连续打卡 $continueSignDays 天" : "点击右侧按钮签到领取喂食次数（签到+20经验）",
                  style: TextStyle(fontSize: 13, color: todaySigned ? _glassGreenDark : const Color(0xFF7088AA)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: todaySigned ? null : _signIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: todaySigned ? Colors.grey.shade300 : const Color(0xFF72A9F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                todaySigned ? "已签到" : "去签到",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: todaySigned ? Colors.grey.shade600 : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStudyTaskCard() {
    final bool canClaim = studyTaskDone && !_hasGainStudyExp;
    // 无今日任务时的文案与按钮态
    final bool noTask = _todayTaskTotal == 0;
    final String subText;
    if (noTask) {
      subText = "今日暂无学习任务，添加任务后才能领取奖励";
    } else if (_hasGainStudyExp) {
      subText = "经验已领取完毕";
    } else if (studyTaskDone) {
      subText = "已完成今日任务，可领取奖励";
    } else {
      subText = "完成今日学习任务后可领取奖励";
    }
    final String btnText;
    if (noTask) {
      btnText = "暂无任务";
    } else if (_hasGainStudyExp) {
      btnText = "已领取";
    } else {
      btnText = "领取奖励";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _glassGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle, color: _glassGreenDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("完成今日学习任务", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF304870))),
                Text(
                  subText,
                  style: TextStyle(fontSize: 13, color: (_hasGainStudyExp || noTask) ? Colors.grey : _glassGreenDark),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: canClaim ? _gainStudyTaskExp : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: canClaim ? Colors.transparent : Colors.grey.shade300,
                border: canClaim
                    ? Border.all(color: _glassGreen.withOpacity(0.35), width: 1.5)
                    : null,
                gradient: canClaim
                    ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _glassGreen.withOpacity(0.45),
                    _glassGreenDark.withOpacity(0.35),
                  ],
                )
                    : null,
                boxShadow: canClaim
                    ? [
                  BoxShadow(
                    color: _glassShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ]
                    : null,
              ),
              child: Text(
                btnText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: canClaim ? const Color(0xFF1F7A3D) : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}