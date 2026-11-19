import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class AccountRestrictedScreen extends ConsumerWidget {
  const AccountRestrictedScreen({super.key});

  Future<void> _openSupport() async {
    final uri = Uri.parse(AppConstants.supportTelegramUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch support URL: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    final isFrozen = profile?.isCurrentlyFrozen ?? false;
    final reason = (profile?.blockReason != null && profile!.blockReason!.trim().isNotEmpty)
        ? profile.blockReason!.trim()
        : 'Причина не указана';
    final until = profile?.blockUntil;

    // If freeze expired or user is no longer restricted, redirect to home
    if (profile != null && !profile.isRestricted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/home');
        }
      });
    }

    String untilStr;
    if (isFrozen) {
      if (until != null) {
        final localUntil = until.toLocal();
        untilStr = DateFormat('dd.MM.yyyy в HH:mm').format(localUntil);
      } else {
        untilStr = 'Срок не указан';
      }
    } else {
      untilStr = 'Блокировка бессрочная';
    }

    final borderColor = isFrozen ? const Color(0xFF38BDF8) : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF16162A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFrozen ? Icons.ac_unit_rounded : Icons.block_rounded,
                        size: 38,
                        color: borderColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isFrozen ? 'Аккаунт временно заморожен' : 'Аккаунт заблокирован',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isFrozen
                          ? 'Администрация временно ограничила доступ к аккаунту.'
                          : 'Доступ к платформе закрыт из-за нарушения правил сообщества.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Причина:',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isFrozen ? 'Срок заморозки:' : 'Срок блокировки:',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isFrozen ? Icons.access_time_rounded : Icons.all_inclusive_rounded,
                                size: 14,
                                color: borderColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  untilStr,
                                  style: TextStyle(
                                    color: borderColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons (Stack on mobile, responsive)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text(
                            'Написать в поддержку',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: _openSupport,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text(
                            'Выйти из аккаунта',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () async {
                            await ref.read(authRepositoryProvider).signOut();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
