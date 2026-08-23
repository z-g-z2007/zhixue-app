import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/backend_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // 校验状态
  String? _accountError;   // 账号错误提示
  String? _nicknameError;
  String? _petNameError;
  String? _confirmError;
  bool _accountChecked = false; // 是否已做后端查重
  bool _accountExists = false;

  // 密码强度：0=空, 1=弱, 2=中, 3=强
  int _passwordStrength = 0;

  @override
  void dispose() {
    _accountController.dispose();
    _nicknameController.dispose();
    _petNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ========================= 校验逻辑 =========================

  /// 手机号校验：11位 + 三大运营商号段
  /// 移动：134-139,147,148,150-152,157-159,178,182-184,187,188,195,197,198
  /// 联通：130-132,145,146,155,156,166,167,171,175,176,185,186,196
  /// 电信：133,149,153,173,174,177,179,180,181,189,190,191,193,199
  static final RegExp _phoneReg = RegExp(
    r'^1(3[4-9]|4[5-9]|5[0-2|5-9]|6[5-6]|7[0-1|5-9]|8[0-9]|9[0-9])\d{8}$',
  );

  /// 邮箱校验
  static final RegExp _emailReg = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// 判断账号类型：'phone' / 'email' / null（无效）
  String? _accountType(String v) {
    if (v.isEmpty) return null;
    if (_phoneReg.hasMatch(v)) return 'phone';
    if (_emailReg.hasMatch(v)) return 'email';
    return null;
  }

  /// 密码强度计算
  /// 返回 0(空) 1(弱) 2(中) 3(强)
  int _calcStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    bool hasLower = RegExp(r'[a-z]').hasMatch(pwd);
    bool hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
    bool hasDigit = RegExp(r'[0-9]').hasMatch(pwd);
    bool hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(pwd);
    int types = 0;
    if (hasLower) types++;
    if (hasUpper) types++;
    if (hasDigit) types++;
    if (hasSpecial) types++;

    // 弱：长度<8，或字符类型只有1种
    if (pwd.length < 8 || types <= 1) return 1;
    // 中：长度>=8 且 字符类型=2种（字母+数字常见组合）
    if (types == 2) return 2;
    // 强：长度>=8 且 字符类型>=3种
    return 3;
  }

  /// 密码是否可提交（至少达到"中"）
  bool get _passwordOk => _passwordStrength >= 2;

  // ========================= 输入监听 =========================

  void _onAccountChanged(String v) {
    final type = _accountType(v.trim());
    String? err;
    if (v.trim().isEmpty) {
      err = null;
    } else if (type == null) {
      err = '请输入有效的手机号或邮箱';
    } else if (type == 'phone') {
      err = null; // 手机号格式正确
    } else {
      err = null; // 邮箱格式正确
    }
    setState(() {
      _accountError = err;
      _accountChecked = false; // 内容变动，查重状态失效
      _accountExists = false;
    });
  }

  void _onPasswordChanged(String v) {
    setState(() {
      _passwordStrength = _calcStrength(v);
    });
    // 同步检查确认密码一致性
    if (_confirmPasswordController.text.isNotEmpty) {
      _checkConfirm();
    }
  }

  void _checkConfirm() {
    final confirm = _confirmPasswordController.text;
    String? err;
    if (confirm.isEmpty) {
      err = null;
    } else if (confirm != _passwordController.text) {
      err = '两次输入的密码不一致';
    } else {
      err = null;
    }
    setState(() => _confirmError = err);
  }

  // ========================= 后端查重 =========================

  Future<void> _checkAccountExists() async {
    final account = _accountController.text.trim();
    if (account.isEmpty || _accountType(account) == null) return;
    try {
      final exists = await BackendService.accountExists(account);
      if (!mounted) return;
      setState(() {
        _accountExists = exists;
        _accountChecked = true;
        if (exists) {
          _accountError = '该账号已被注册';
        } else {
          _accountError = null;
        }
      });
    } catch (_) {
      // 查重失败不阻塞，提交时后端会再校验
    }
  }

  // ========================= 提交注册 =========================

  Future<void> _handleRegister() async {
    // 先收起键盘
    FocusScope.of(context).unfocus();

    final account = _accountController.text.trim();
    final nickname = _nicknameController.text.trim();
    final petName = _petNameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    // 前端逐项校验
    String? accountErr;
    if (account.isEmpty) {
      accountErr = '请输入账号';
    } else if (_accountType(account) == null) {
      accountErr = '请输入有效的手机号或邮箱';
    }

    String? nicknameErr;
    if (nickname.isEmpty) {
      nicknameErr = '请输入账号昵称';
    }

    String? petErr;
    if (petName.isEmpty) {
      petErr = '请输入宠物名称';
    }

    String? pwdErr;
    if (password.isEmpty) {
      pwdErr = '请输入密码';
    } else if (!_passwordOk) {
      pwdErr = '密码太弱，至少8位且包含字母和数字';
    }

    String? confirmErr;
    if (confirm.isEmpty) {
      confirmErr = '请再次输入密码';
    } else if (confirm != password) {
      confirmErr = '两次输入的密码不一致';
    }

    if (accountErr != null || nicknameErr != null || petErr != null ||
        pwdErr != null || confirmErr != null) {
      setState(() {
        _accountError = accountErr ?? (_accountChecked && _accountExists ? '该账号已被注册' : _accountError);
        _nicknameError = nicknameErr;
        _petNameError = petErr;
        _confirmError = confirmErr;
      });
      _showSnackBar(pwdErr ?? accountErr ?? nicknameErr ?? petErr ?? confirmErr!);
      return;
    }

    // 若未查重，先查一次
    if (!_accountChecked) {
      await _checkAccountExists();
      if (!mounted) return;
      if (_accountExists) {
        _showSnackBar('该账号已被注册');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await BackendService.register(
        account: account,
        password: password,
        nickname: nickname,
        petName: petName,
      );
      if (!mounted) return;
      // 注册成功，回到登录页让用户手动登录（把账号带回预填）
      _showSnackBar('注册成功，请登录');
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop(account);
    } on PlatformException catch (e) {
      _showSnackBar(e.message ?? '注册失败');
    } catch (e) {
      _showSnackBar('注册失败：$e');
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

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF639CE8);
    const Color bgPage = Color(0xFFF7F9FC);
    const Color textMain = Color(0xFF222222);
    const Color textSub = Color(0xFF777777);

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        title: const Text('注册账号', style: TextStyle(color: textMain, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: textMain,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '创建你的至学账号',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: textSub),
                ),
                const SizedBox(height: 28),

                // 账号
                _buildLabel('账号（手机号或邮箱）'),
                _buildTextField(
                  controller: _accountController,
                  hint: '请输入手机号或邮箱',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _accountError,
                  onChanged: (v) {
                    _onAccountChanged(v);
                    // 输入完整时自动查重
                    final type = _accountType(v.trim());
                    if (type != null) {
                      _checkAccountExists();
                    }
                  },
                  suffix: _accountChecked && !_accountExists && _accountError == null
                      ? const Icon(Icons.check_circle, color: Color(0xFF63B895), size: 20)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  '支持中国大陆手机号（移动/联通/电信）或有效邮箱',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                ),
                const SizedBox(height: 16),

                // 昵称
                _buildLabel('账号昵称'),
                _buildTextField(
                  controller: _nicknameController,
                  hint: '请输入昵称',
                  icon: Icons.badge_outlined,
                  errorText: _nicknameError,
                  onChanged: (v) => setState(() {
                    _nicknameError = v.trim().isEmpty ? '请输入账号昵称' : null;
                  }),
                ),
                const SizedBox(height: 16),

                // 宠物名称
                _buildLabel('宠物名称'),
                _buildTextField(
                  controller: _petNameController,
                  hint: '给你的小猫起个名字',
                  icon: Icons.pets_outlined,
                  errorText: _petNameError,
                  onChanged: (v) => setState(() {
                    _petNameError = v.trim().isEmpty ? '请输入宠物名称' : null;
                  }),
                ),
                const SizedBox(height: 16),

                // 密码
                _buildLabel('密码'),
                _buildTextField(
                  controller: _passwordController,
                  hint: '至少8位，含字母和数字',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  errorText: null,
                  onChanged: _onPasswordChanged,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 密码强度指示器
                _buildStrengthBar(),
                const SizedBox(height: 4),
                Text(
                  _strengthHint(),
                  style: TextStyle(
                    fontSize: 11,
                    color: _passwordStrength == 0
                        ? const Color(0xFFAAAAAA)
                        : (_passwordStrength == 1
                            ? const Color(0xFFE57373)
                            : _passwordStrength == 2
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFF66BB6A)),
                  ),
                ),
                const SizedBox(height: 16),

                // 确认密码
                _buildLabel('确认密码'),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: '请再次输入密码',
                  icon: Icons.lock_outline,
                  obscure: _obscureConfirm,
                  errorText: _confirmError,
                  onChanged: (_) => _checkConfirm(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFFAAAAAA),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 注册按钮
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            '注册',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF555555)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? errorText,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF639CE8), size: 20),
        suffixIcon: suffix,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF639CE8), width: 1.2),
        ),
        errorText: errorText,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
    );
  }

  /// 密码强度条：三段
  Widget _buildStrengthBar() {
    final List<Color> colors;
    switch (_passwordStrength) {
      case 1:
        colors = [const Color(0xFFE57373), const Color(0xFFE0E0E0), const Color(0xFFE0E0E0)];
        break;
      case 2:
        colors = [const Color(0xFFFFB74D), const Color(0xFFFFB74D), const Color(0xFFE0E0E0)];
        break;
      case 3:
        colors = [const Color(0xFF66BB6A), const Color(0xFF66BB6A), const Color(0xFF66BB6A)];
        break;
      default:
        colors = [const Color(0xFFE0E0E0), const Color(0xFFE0E0E0), const Color(0xFFE0E0E0)];
    }
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  String _strengthHint() {
    switch (_passwordStrength) {
      case 1:
        return '弱：密码太简单，请至少8位且包含字母和数字';
      case 2:
        return '中：密码强度合格';
      case 3:
        return '强：密码强度很高';
      default:
        return '至少8位，建议包含大小写字母、数字和特殊字符';
    }
  }
}
