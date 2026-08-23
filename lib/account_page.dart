import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart' show isLoggedInNotifier, userNicknameNotifier, userAccountIdNotifier, selectedPetNotifier, petNameNotifier, petExpNotifier, petLevelNotifier, streakNotifier, userAvatarNotifier;
import 'services/backend_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const List<Map<String, dynamic>> _petOptions = [
    {'name': '小猫', 'icon': Icons.pets, 'color': Color(0xFF639CE8)},
    {'name': '小狗', 'icon': Icons.cruelty_free, 'color': Color(0xFFE8A863)},
  ];

  bool _isEditingName = false;
  bool _isEditingNick = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nickController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    selectedPetNotifier.addListener(_onChanged);
    petNameNotifier.addListener(_onChanged);
    userNicknameNotifier.addListener(_onChanged);
    userAccountIdNotifier.addListener(_onChanged);
    userAvatarNotifier.addListener(_onChanged);
    petExpNotifier.addListener(_onChanged);
    petLevelNotifier.addListener(_onChanged);
    streakNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    selectedPetNotifier.removeListener(_onChanged);
    petNameNotifier.removeListener(_onChanged);
    userNicknameNotifier.removeListener(_onChanged);
    userAccountIdNotifier.removeListener(_onChanged);
    userAvatarNotifier.removeListener(_onChanged);
    petExpNotifier.removeListener(_onChanged);
    petLevelNotifier.removeListener(_onChanged);
    streakNotifier.removeListener(_onChanged);
    _nameController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Color(0xFFE57373)),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await BackendService.logout();
      } catch (_) {}
      if (!mounted) return;
      // 先 pop 回根，避免 account_page 盖住 LoginPage
      Navigator.of(context).popUntil((route) => route.isFirst);
      isLoggedInNotifier.value = false;
    }
  }

  // 从相册选照片作为头像
  Future<void> _pickAvatar() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (photo == null) return;
      // 复制到 app 文档目录，得到持久路径
      final dir = await getApplicationDocumentsDirectory();
      final String ext = photo.path.split('.').last.toLowerCase();
      final String destPath = '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final File src = File(photo.path);
      await src.copy(destPath);
      // 存路径到后端
      final r = await BackendService.updateProfile(avatar: destPath);
      userAvatarNotifier.value = r['avatar'] as String;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择头像失败：$e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  // 内联编辑昵称
  void _startEditNick() {
    _nickController.text = userNicknameNotifier.value;
    setState(() => _isEditingNick = true);
  }

  Future<void> _confirmEditNick() async {
    final name = _nickController.text.trim();
    if (name.isEmpty) {
      if (mounted) setState(() => _isEditingNick = false);
      return;
    }
    try {
      final r = await BackendService.updateProfile(nickname: name);
      userNicknameNotifier.value = r['nickname'] as String;
    } catch (_) {}
    if (mounted) setState(() => _isEditingNick = false);
  }

  void _startEditName() {
    _nameController.text = petNameNotifier.value;
    setState(() => _isEditingName = true);
  }

  void _cancelEditName() {
    setState(() => _isEditingName = false);
  }

  Future<void> _confirmEditName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) setState(() => _isEditingName = false);
      return;
    }
    try {
      final r = await BackendService.updatePet(petName: name);
      petNameNotifier.value = r['pet_name'] as String;
    } catch (_) {
      // 静默处理
    }
    if (mounted) setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF639CE8);
    // 整体极浅页面底色
    const Color pageBg = Color(0xFFFAFBFD);
    const Color textMain = Color(0xFF212121);
    const Color textGray = Color(0xFF787878);
    const Color lightBg = Color(0xFFF4F7FB);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('账号信息'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserCard(primary, textMain, textGray, lightBg),
            const SizedBox(height: 12),
            _buildPetPanel(primary, textMain, textGray, lightBg),
            const SizedBox(height: 12),
            _buildInfoList(primary, textMain, textGray, lightBg),
            const SizedBox(height: 24),
            _buildLogoutBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Color primary, Color textMain, Color textGray, Color lightBg) {
    // avatar 可能是文件路径（相册选的）或预设 key
    final String avatar = userAvatarNotifier.value;
    final bool isFile = avatar.startsWith('/') || avatar.contains('\\') || avatar.startsWith('file:');
    // 构建头像 Widget
    Widget avatarWidget;
    if (isFile) {
      avatarWidget = ClipOval(
        child: Image.file(
          File(avatar),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.person, size: 28, color: primary),
        ),
      );
    } else {
      // 预设 key 兜底（student/cat/dog...）
      const Map<String, IconData> iconMap = {
        'student': Icons.school,
        'cat': Icons.pets_outlined,
        'dog': Icons.cruelty_free_outlined,
        'star': Icons.star_rounded,
        'book': Icons.menu_book_outlined,
        'palette': Icons.palette_outlined,
      };
      avatarWidget = Icon(iconMap[avatar] ?? Icons.school, size: 28, color: primary);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _pickAvatar,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isFile ? null : primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: avatarWidget,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isEditingNick
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nickController,
                                  autofocus: true,
                                  maxLength: 10,
                                  decoration: InputDecoration(
                                    hintText: '输入昵称',
                                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                                    filled: true,
                                    fillColor: lightBg,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    counterText: '',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TextButton(
                                onPressed: () => setState(() => _isEditingNick = false),
                                style: TextButton.styleFrom(minimumSize: const Size(40, 30)),
                                child: const Text('取消', style: TextStyle(fontSize: 13)),
                              ),
                              ElevatedButton(
                                onPressed: _confirmEditNick,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  minimumSize: const Size(40, 30),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('确定', style: TextStyle(fontSize: 13, color: Colors.white)),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Text(
                                userNicknameNotifier.value,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textMain),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _startEditNick,
                                child: Icon(Icons.edit_outlined, size: 16, color: primary),
                              ),
                            ],
                          ),
                    const SizedBox(height: 3),
                    Text(
                      '账号：${userAccountIdNotifier.value}',
                      style: TextStyle(fontSize: 12, color: textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickAvatar,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined, size: 14, color: textGray),
                  const SizedBox(width: 4),
                  Text('从相册更换头像', style: TextStyle(fontSize: 12, color: textGray)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetPanel(Color primary, Color textMain, Color textGray, Color lightBg) {
    final selPet = selectedPetNotifier.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets, size: 19, color: primary),
              const SizedBox(width: 6),
              Text(
                '我的宠物',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textMain),
              ),
              const Spacer(),
              Text('当前：$selPet', style: TextStyle(fontSize: 12, color: textGray)),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: _petOptions.map((item) {
              final isSelected = item['name'] == selPet;
              return Expanded(
                child: InkWell(
                  onTap: () async {
                    final petType = item['name'] as String;
                    try {
                      final r = await BackendService.updatePet(petType: petType);
                      selectedPetNotifier.value = r['pet_type'] as String;
                      petExpNotifier.value = (r['pet_exp'] as num).toInt();
                      petLevelNotifier.value = (r['pet_level'] as num).toInt();
                    } catch (_) {
                      // 静默处理
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: item == _petOptions.first ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      // 仅选中时淡淡底色，去掉粗边框、大阴影
                      color: isSelected ? item['color'].withOpacity(0.07) : lightBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected ? item['color'].withOpacity(0.12) : Color(0xFFE9EDF3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item['icon'],
                            size: 28,
                            color: isSelected ? item['color'] : Color(0xFFB0B8C4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                            color: isSelected ? item['color'] : textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          _isEditingName
              ? _buildNameEditRow(primary, textMain, textGray, lightBg)
              : _buildNameDisplayRow(primary, textMain, textGray, lightBg),
        ],
      ),
    );
  }

  Widget _buildNameDisplayRow(Color primary, Color textMain, Color textGray, Color lightBg) {
    return InkWell(
      onTap: _startEditName,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: lightBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 17, color: primary),
            const SizedBox(width: 8),
            Text('宠物昵称', style: TextStyle(fontSize: 13, color: textGray)),
            const Spacer(),
            Text(
              petNameNotifier.value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMain),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFFC2C8D3)),
          ],
        ),
      ),
    );
  }

  Widget _buildNameEditRow(Color primary, Color textMain, Color textGray, Color lightBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 8,
              decoration: InputDecoration(
                hintText: '输入宠物昵称',
                hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _cancelEditName,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4),minimumSize: const Size(40,30)),
            child: const Text('取消',style: TextStyle(fontSize:13)),
          ),
          SizedBox(width:2),
          ElevatedButton(
            onPressed: _confirmEditName,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal:8,vertical:4),
              minimumSize: const Size(40,30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('确定',style: TextStyle(fontSize:13,color:Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoList(Color primary, Color textMain, Color textGray, Color lightBg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _infoItem(primary, Icons.badge_outlined, '账号ID', userAccountIdNotifier.value, textMain, textGray),
          _divider(),
          _infoItem(primary, Icons.pets_outlined, '宠物等级', 'Lv. ${petLevelNotifier.value}', textMain, textGray),
          _divider(),
          _infoItem(primary, Icons.local_fire_department_outlined, '连续打卡', '${streakNotifier.value} 天', textMain, textGray),
        ],
      ),
    );
  }

  Widget _infoItem(Color primary, IconData icon, String label, String val, Color textMain, Color textGray) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 19, color: primary),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(fontSize:14,color: textGray)),
          const Spacer(),
          Text(val, style: TextStyle(fontSize:14,color: textMain, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
    );
  }

  Widget _buildLogoutBtn() {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: _handleLogout,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              '退出登录',
              style: TextStyle(fontSize: 15, color: Color(0xFFE57373)),
            ),
          ),
        ),
      ),
    );
  }
}
