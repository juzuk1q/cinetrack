import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/top_notification.dart';

class AdminUserDialogs {
  static void showManageTitlesDialog(BuildContext context, WidgetRef ref, UserProfile targetUser) {
    final titleCtrl = TextEditingController(text: targetUser.customTitle ?? '');
    final currentUnlocked = List<String>.from(targetUser.unlockedTitles);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: Color(0xFFD8B4FE), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Титулы и плюшки: ${targetUser.displayName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пользователь: @${targetUser.handle} (${targetUser.email})',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Активный отображаемый титул:',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Введите любой титул (например: Кинокритик 👑, VIP 💎)...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF141424) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.transparent : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.transparent : const Color(0xFFCBD5E1)),
                      ),
                      suffixIcon: titleCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                titleCtrl.clear();
                                setDlgState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Быстрый выбор из каталога достижений CineTrack:',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserAchievementsCatalog.list.map((ach) {
                      final isSelected = titleCtrl.text.trim() == ach.title;
                      return ActionChip(
                        avatar: Text(ach.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(
                          ach.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF141424),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF9F67FF) : Colors.white12,
                        ),
                        onPressed: () {
                          setDlgState(() => titleCtrl.text = ach.title);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  const Text(
                    'Разблокированные награды & перки профиля:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141424),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(6),
                      itemCount: UserAchievementsCatalog.list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, idx) {
                        final ach = UserAchievementsCatalog.list[idx];
                        final hasPerk = currentUnlocked.contains(ach.id);
                        return CheckboxListTile(
                          dense: true,
                          value: hasPerk,
                          activeColor: const Color(0xFF7C3AED),
                          title: Row(
                            children: [
                              Text(ach.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ach.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            ach.description,
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                if (!currentUnlocked.contains(ach.id)) {
                                  currentUnlocked.add(ach.id);
                                }
                              } else {
                                currentUnlocked.remove(ach.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: () async {
                final newTitle = titleCtrl.text.trim();
                Navigator.of(ctx, rootNavigator: true).pop();

                await ref.read(adminUsersProvider.notifier).updateUserTitle(
                      targetUser.id,
                      newTitle.isNotEmpty ? newTitle : null,
                      unlockedTitles: currentUnlocked,
                    );

                if (!context.mounted) return;
                TopNotification.showSuccess(
                  context,
                  'Титул «${newTitle.isNotEmpty ? newTitle : "Сброшен"}» успешно сохранен для ${targetUser.displayName} ✨',
                  title: 'Титул обновлен',
                );
              },
              child: const Text('Сохранить титул & плюшки'),
            ),
          ],
        ),
      ),
    );
  }

  static void showBlockFreezeDialog(BuildContext context, WidgetRef ref, UserProfile targetUser) {
    bool isFreeze = true;
    int freezeDays = 7;
    final reasonCtrl = TextEditingController(text: 'Нарушение правил сообщества CineTrack');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
          title: Row(
            children: [
              Icon(
                isFreeze ? Icons.ac_unit_rounded : Icons.block_rounded,
                color: isFreeze ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 10),
              Text(
                isFreeze ? 'Заморозка аккаунта' : 'Блокировка аккаунта',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Пользователь: ${targetUser.displayName} (@${targetUser.handle})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetUser.email,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Тип ограничения:',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.ac_unit_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Заморозка ❄️'),
                          ],
                        ),
                        selected: isFreeze,
                        selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        onSelected: (val) {
                          if (val) setDlgState(() => isFreeze = true);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Блокировка 🚫'),
                          ],
                        ),
                        selected: !isFreeze,
                        selectedColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
                        onSelected: (val) {
                          if (val) setDlgState(() => isFreeze = false);
                        },
                      ),
                    ),
                  ],
                ),
                if (isFreeze) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Срок заморозки:',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1 день'),
                        selected: freezeDays == 1,
                        onSelected: (val) => setDlgState(() => freezeDays = 1),
                      ),
                      ChoiceChip(
                        label: const Text('7 дней'),
                        selected: freezeDays == 7,
                        onSelected: (val) => setDlgState(() => freezeDays = 7),
                      ),
                      ChoiceChip(
                        label: const Text('30 дней'),
                        selected: freezeDays == 30,
                        onSelected: (val) => setDlgState(() => freezeDays = 30),
                      ),
                      ChoiceChip(
                        label: const Text('Бессрочно'),
                        selected: freezeDays == 0,
                        onSelected: (val) => setDlgState(() => freezeDays = 0),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Причина ограничения:',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Укажите причину (спам, оскорбления, запрещенный контент)...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    fillColor: isDark ? const Color(0xFF141424) : const Color(0xFFF1F5F9),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.transparent : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.transparent : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFreeze ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
              ),
              onPressed: () async {
                final reason = reasonCtrl.text.trim().isEmpty
                    ? 'Нарушение правил платформы'
                    : reasonCtrl.text.trim();
                final duration = (isFreeze && freezeDays > 0)
                    ? Duration(days: freezeDays)
                    : null;

                Navigator.of(ctx, rootNavigator: true).pop();
                await ref.read(adminUsersProvider.notifier).blockOrFreezeUser(
                      targetUser.id,
                      isFreeze: isFreeze,
                      reason: reason,
                      duration: duration,
                    );

                if (!context.mounted) return;
                TopNotification.showWarning(
                  context,
                  isFreeze
                      ? 'Аккаунт «${targetUser.displayName}» заморожен'
                      : 'Аккаунт «${targetUser.displayName}» заблокирован',
                  title: isFreeze ? 'Заморозка аккаунта ❄️' : 'Блокировка аккаунта 🚫',
                );
              },
              child: Text(isFreeze ? 'Заморозить' : 'Заблокировать'),
            ),
          ],
        ),
      ),
    );
  }

}
