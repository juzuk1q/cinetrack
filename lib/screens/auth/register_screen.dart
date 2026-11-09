import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).signUp(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final authState = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (authState.hasError) {
      final err = authState.error.toString();
      if (err.contains('Ссылка для активации') ||
          err.contains('EmailConfirmationRequiredException')) {
        _showConfirmationDialog(_emailController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } else {
      _showConfirmationDialog(_emailController.text.trim());
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    try {
      await ref.read(authNotifierProvider.notifier).signInWithOAuth(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка авторизации: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showConfirmationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Подтвердите почту', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'На адрес $email отправлено письмо со ссылкой для активации аккаунта.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Пожалуйста, перейдите по ссылке из письма (проверьте также папку «Спам») и затем выполните вход.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('Перейти ко входу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(theme),
                const SizedBox(height: 28),

                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16162A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Создать аккаунт',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Регистрация по логину, почте и паролю',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Username
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Имя пользователя (логин) *',
                              hintText: 'ваш логин',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                              prefixIcon: const Icon(Icons.person_outline_rounded,
                                  color: Color(0xFF9F67FF)),
                              filled: true,
                              fillColor: const Color(0xFF202038),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Введите имя пользователя';
                              }
                              if (v.trim().length < 3) {
                                return 'Минимум 3 символа';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Электронная почта *',
                              hintText: 'например: name@example.com',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                              prefixIcon: const Icon(Icons.email_outlined,
                                  color: Color(0xFF9F67FF)),
                              filled: true,
                              fillColor: const Color(0xFF202038),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Введите email';
                              }
                              if (!v.contains('@')) {
                                return 'Введите корректный email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Пароль *',
                              hintText: 'минимум 8 символов (A-Z, a-z, 0-9, спецсимвол)',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                              prefixIcon: const Icon(Icons.lock_outline_rounded,
                                  color: Color(0xFF9F67FF)),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Показать пароли'
                                    : 'Скрыть пароли',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white60,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF202038),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Введите пароль';
                              }
                              if (v.length < 8) {
                                return 'Минимум 8 символов';
                              }
                              if (!v.contains(RegExp(r'[A-Z]'))) {
                                return 'Нужна хотя бы одна заглавная буква (A-Z)';
                              }
                              if (!v.contains(RegExp(r'[a-z]'))) {
                                return 'Нужна хотя бы одна строчная буква (a-z)';
                              }
                              if (!v.contains(RegExp(r'[0-9]'))) {
                                return 'Нужна хотя бы одна цифра (0-9)';
                              }
                              if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\\[\]/~`]'))) {
                                return 'Нужен хотя бы один спецсимвол (!@#\$%^&*...)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Confirm password
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Подтвердите пароль *',
                              hintText: 'повторите пароль',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                              prefixIcon: const Icon(Icons.lock_reset_rounded,
                                  color: Color(0xFF9F67FF)),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Показать пароли'
                                    : 'Скрыть пароли',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white60,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF202038),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Пароли не совпадают';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: isLoading ? null : _submit,
                              icon: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_rounded, size: 20),
                              label: Text(
                                isLoading ? 'Создание...' : 'Зарегистрироваться',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'ИЛИ ВОЙТИ ЧЕРЕЗ',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // OAuth Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFF202038),
                                  ),
                                  onPressed: isLoading ? null : () => _signInWithOAuth(OAuthProvider.google),
                                  icon: Image.network(
                                    'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 22),
                                  ),
                                  label: const Text(
                                    'Google',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF5865F2)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFF5865F2).withValues(alpha: 0.15),
                                  ),
                                  onPressed: isLoading ? null : () => _signInWithOAuth(OAuthProvider.discord),
                                  icon: const Icon(Icons.sports_esports_rounded, color: Color(0xFF8EA1FF), size: 18),
                                  label: const Text(
                                    'Discord',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8EA1FF)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Уже есть аккаунт?',
                                style: TextStyle(color: Colors.white60),
                              ),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text(
                                  'Войти',
                                  style: TextStyle(
                                    color: Color(0xFF9F67FF),
                                    fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFE040FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.movie_filter_rounded,
              size: 42, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'CineTrack',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
