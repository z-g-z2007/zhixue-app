import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'home_page.dart';
import 'add_page.dart';
import 'mine_page.dart';
import 'login_page.dart';
import 'services/backend_service.dart';

// ===== 全局用户状态 =====
final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> isAppReadyNotifier = ValueNotifier<bool>(false); // 启动画面状态
final ValueNotifier<String> userNicknameNotifier = ValueNotifier<String>('好好学习的小明');
final ValueNotifier<String> userAccountIdNotifier = ValueNotifier<String>('student_001236');
final ValueNotifier<String> selectedPetNotifier = ValueNotifier<String>('小猫');
final ValueNotifier<String> petNameNotifier = ValueNotifier<String>('小猫咪');
final ValueNotifier<String> userAvatarNotifier = ValueNotifier<String>('student');
// 新增：宠物经验 / 等级 / 连续打卡天数
final ValueNotifier<int> petExpNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> petLevelNotifier = ValueNotifier<int>(1);
final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化本地后端（写入测试账号 test/123456）
  try {
    await BackendService.init();
  } catch (_) {
    // web 模式无 MethodChannel，忽略错误
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '至学',
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'HK'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7BA7E0)),
        useMaterial3: true,
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: isAppReadyNotifier,
        builder: (context, isReady, _) {
          if (!isReady) {
            return const SplashScreen();
          }
          return ValueListenableBuilder<bool>(
            valueListenable: isLoggedInNotifier,
            builder: (context, isLoggedIn, _) {
              return isLoggedIn ? const MainScaffold() : const LoginPage();
            },
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 启动画面：全屏展示 assets/qidong.png
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  Future<void> _startCountdown() async {
    // 启动期间尝试恢复登录 session（与启动图展示并行）
    try {
      final r = await BackendService.restoreSession();
      if (r != null) {
        // 恢复成功，填充全局用户状态
        userNicknameNotifier.value = r['nickname'] as String? ?? '';
        userAccountIdNotifier.value = r['account'] as String? ?? '';
        userAvatarNotifier.value = r['avatar'] as String? ?? 'student';
        selectedPetNotifier.value = r['pet_type'] as String? ?? '小猫';
        petNameNotifier.value = r['pet_name'] as String? ?? '小猫咪';
        petExpNotifier.value = (r['pet_exp'] as num?)?.toInt() ?? 0;
        petLevelNotifier.value = (r['pet_level'] as num?)?.toInt() ?? 1;
        streakNotifier.value = (r['streak'] as num?)?.toInt() ?? 0;
        isLoggedInNotifier.value = true;
      }
    } catch (_) {
      // web 模式无 MethodChannel，忽略
    }
    // 至少展示 2.5 秒启动图作为视觉缓冲
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    // 直接更新状态，切换主界面，不使用 Navigator 避免黑屏
    isAppReadyNotifier.value = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 重要：必须设置不透明的背景色，防止底层黑色暴露。作为图片加载失败时的兜底背景
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/qidong.png',
          fit: BoxFit.cover, // 使用 cover 避免图片变形
          // 关键：errorBuilder 处理图片加载失败的情况，显示空白页而非红叉
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            // 返回一个干净的空白 Container，作为缓冲页
            return Container(
              color: Colors.white,
            );
          },
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  // 用于通知 AddPage 当前是否处于激活状态，以控制视频播放/暂停
  final ValueNotifier<int> _indexNotifier = ValueNotifier<int>(0);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      AddPage(activeIndexNotifier: _indexNotifier),
      const MinePage(),
    ];
  }

  @override
  void dispose() {
    _indexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _indexNotifier.value = index;
        },
      ),
    );
  }
}

const Color _kActiveColor = Color(0xFF7BA7E0);
const Color _kInactiveColor = Color(0xFFB8C5D6);

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, Icons.home, '首页'),
            Expanded(
              child: Center(
                child: _AddButton(
                  active: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),
            ),
            _navItem(2, Icons.person_outline, Icons.person, '我的'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData inactive, IconData active, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? _kActiveColor : _kInactiveColor;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? active : inactive,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  const _AddButton({required this.active, required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.85 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: widget.active
                ? const LinearGradient(
                    colors: [Color(0xFF7BA7E0), Color(0xFF9B8FD9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.active ? null : const Color(0xFFEEF4FC),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.08 : 0.12),
                blurRadius: _pressed ? 2 : 8,
                offset: Offset(0, _pressed ? 1 : 4),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            color: widget.active ? Colors.white : _kActiveColor,
            size: 30,
          ),
        ),
      ),
    );
  }
}
