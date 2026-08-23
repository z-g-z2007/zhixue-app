import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart' show isLoggedInNotifier, userNicknameNotifier, userAccountIdNotifier, selectedPetNotifier, petNameNotifier, petExpNotifier, petLevelNotifier, streakNotifier, userAvatarNotifier;
import 'register_page.dart';
import 'services/backend_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      _showSnackBar('请输入账号');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showSnackBar('请输入密码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final r = await BackendService.login(account, _passwordController.text);
      if (!mounted) return;
      userNicknameNotifier.value = r['nickname'] as String? ?? account;
      userAccountIdNotifier.value = r['account'] as String? ?? account;
      userAvatarNotifier.value = r['avatar'] as String? ?? 'student';
      selectedPetNotifier.value = r['pet_type'] as String? ?? '小猫';
      petNameNotifier.value = r['pet_name'] as String? ?? '小猫咪';
      petExpNotifier.value = (r['pet_exp'] as num?)?.toInt() ?? 0;
      petLevelNotifier.value = (r['pet_level'] as num?)?.toInt() ?? 1;
      streakNotifier.value = (r['streak'] as num?)?.toInt() ?? 0;
      isLoggedInNotifier.value = true;
    } on PlatformException catch (e) {
      _showSnackBar(e.message ?? '登录失败');
    } catch (e) {
      _showSnackBar('登录失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 基础配色：简约干净浅蓝体系
    const Color primaryColor = Color(0xFF639CE8);
    const Color bgPage = Color(0xFFF7F9FC);
    const Color textMain = Color(0xFF222222);
    const Color textSub = Color(0xFF777777);

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '至学',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '登录账号开始学习',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: textSub),
                ),
                const SizedBox(height: 48),

                // 账号输入框
                TextField(
                  controller: _accountController,
                  decoration: InputDecoration(
                    hintText: '请输入账号',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                    prefixIcon: const Icon(Icons.person_outline, color: primaryColor, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 15, color: textMain),
                ),
                const SizedBox(height: 12),

                // 密码输入框
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '请输入密码',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                    prefixIcon: const Icon(Icons.lock_outline, color: primaryColor, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFFAAAAAA),
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 15, color: textMain),
                ),
                const SizedBox(height: 32),

                // 登录按钮：纯色浅蓝，取消渐变、厚重阴影、超大字间距
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      '登录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 底部注册文字
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '还没有账号？',
                      style: TextStyle(fontSize: 13, color: textSub),
                    ),
                    TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<String>(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                        // 注册成功后把账号预填到输入框
                        if (result != null && result.isNotEmpty) {
                          _accountController.text = result;
                        }
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
                      child: Text(
                        '立即注册',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}