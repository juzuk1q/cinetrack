import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';

class AccountRestrictedScreen extends ConsumerWidget {
  const AccountRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    final isFrozen = profile?.isCurrentlyFrozen ?? false;
    final reason = profile?.blockReason ?? 'Нарушение правил сообщества CineTrack';
    final until = profile?.blockUntil;

    String untilStr = '';
    if (until != null) {
      untilStr = DateFormat('dd.MM.yyyy в HH:mm').format(until);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFF16162A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isFrozen ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFrozen ? const Color(0xFF38BDF8) : const Color(0xFFEF4444))
                        .withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: (isFrozen ? const Color(0xFF38BDF8) : const Color(0xFFEF4444))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFrozen ? Icons.ac_unit_rounded : Icons.gavel_rounded,
                      size: 42,
                      color: isFrozen ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isFrozen ? 'Аккаунт временно заморожен' : 'Доступ к аккаунту заблокирован',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFrozen
                        ? 'Администрация платформы ограничила доступ к аккаунту на время проверки.'
                        : 'Ваш аккаунт был навсегда заблокирован за грубое нарушение правил платформы.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
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
                          'Причина ограничения:',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reason,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (isFrozen && untilStr.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Срок окончания заморозки:',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Text(
                                untilStr,
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B2D31),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Выйти из аккаунта', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
