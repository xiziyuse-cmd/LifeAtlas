import 'package:flutter/material.dart';

import '../../../core/auth/ai_auth_session.dart';

class AiAuthPage extends StatefulWidget {
  const AiAuthPage({super.key, required this.session});

  final AiAuthSession session;

  @override
  State<AiAuthPage> createState() => _AiAuthPageState();
}

class _AiAuthPageState extends State<AiAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await widget.session.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      _passwordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI 服务登录成功')));
    } on AiAuthenticationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已退出 AI 服务账号')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 服务账号')),
      body: AnimatedBuilder(
        animation: widget.session,
        builder: (context, _) {
          if (!widget.session.isConfigured) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前安装包尚未配置 AI 账号服务地址'),
              ),
            );
          }
          if (widget.session.isAuthenticated) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '已登录',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(widget.session.username ?? 'LifeAtlas 用户'),
                        const SizedBox(height: 8),
                        const Text(
                          '访问令牌会自动续期，账号密码不会保存在安装包中。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  key: const ValueKey('ai-auth-logout'),
                  onPressed: widget.session.busy ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                ),
              ],
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '登录后使用图片识别和预购分析',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('账号凭据只发送到你的 Cloudflare Worker，不进入 APK 或 Git。'),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('ai-auth-username'),
                  controller: _usernameController,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '账号',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? '请输入账号' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('ai-auth-password'),
                  controller: _passwordController,
                  autofillHints: const [AutofillHints.password],
                  obscureText: _obscurePassword,
                  onFieldSubmitted: (_) =>
                      widget.session.busy ? null : _login(),
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? '请输入密码' : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('ai-auth-login'),
                  onPressed: widget.session.busy ? null : _login,
                  icon: widget.session.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(widget.session.busy ? '登录中…' : '登录'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
