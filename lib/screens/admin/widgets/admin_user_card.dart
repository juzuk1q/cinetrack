import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/top_notification.dart';
import 'admin_user_dialogs.dart';

class AdminUserCard extends ConsumerWidget {
  final UserProfile user;
  final UserProfile currentActor;
  final User? currentUser;
  final bool isDark;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.currentActor,
    required this.currentUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  
    final isSelf = user.id == currentUser?.id ||
        (user.email.isNotEmpty &&
            currentUser?.email != null &&
            user.email.toLowerCase() == currentUser!.email!.toLowerCase());

    final canManage = currentActor.canManage(user);
    final isRestricted = user.isRestricted;

    Color badgeBg;
    Color badgeText;
    Color badgeBorder;

    switch (user.role) {
      case 'admin':
        badgeBg = isDark
            ? const Color(0xFFEAB308).withValues(alpha: 0.25)
            : const Color(0xFFFEF08A);
        badgeText = isDark ? const Color(0xFFFDE047) : const Color(0xFFA16207);
        badgeBorder = const Color(0xFFEAB308).withValues(alpha: 0.6);
        break;
      case 'moderator':
        badgeBg = isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.25)
            : const Color(0xFFE0E7FF);
        badgeText = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
        badgeBorder = const Color(0xFF6366F1).withValues(alpha: 0.6);
        break;
      case 'user':
      default:
        badgeBg = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
        badgeText = isDark ? Colors.white70 : const Color(0xFF64748B);
        badgeBorder = isDark ? Colors.white24 : const Color(0xFFCBD5E1);
        break;
    }

    return Card(
      color: isDark ? const Color(0xFF16162A) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelf
              ? const Color(0xFF7C3AED).withValues(alpha: 0.8)
              : (user.isBlocked
                  ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                  : (user.isCurrentlyFrozen
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                      : (user.role == 'admin'
                          ? const Color(0xFFEAB308).withValues(alpha: 0.5)
                          : (isDark ? Colors.white10 : const Color(0xFFE2E8F0))))),
          width: isSelf ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // User Avatar (clickable to view public profile)
            Tooltip(
              message: 'Открыть профиль @${user.handle}',
              child: InkWell(
                onTap: () => context.go('/user/${user.handle}'),
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: user.isBlocked
                      ? const Color(0xFFEF4444)
                      : (user.role == 'admin'
                          ? const Color(0xFFEAB308)
                          : (user.role == 'moderator'
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF7C3AED))),
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // User Info (Name, Username, Role Badge, Title, Email)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/user/${user.handle}'),
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '@${user.handle}',
                        style: TextStyle(
                            color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),

                      // System Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorder, width: 0.8),
                        ),
                        child: Text(
                          user.fullRoleTitle,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      // "You" badge indicator
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                                : const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: isDark ? const Color(0xFF9F67FF) : const Color(0xFF8B5CF6)),
                          ),
                          child: Text(
                            'ВЫ',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6D28D9),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Text(
                        user.email,
                        style: TextStyle(
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            fontSize: 12),
                      ),
                      const SizedBox(width: 10),

                      // Title / Badge display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E1065).withValues(alpha: 0.6)
                              : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF9F67FF).withValues(alpha: 0.4)
                                  : const Color(0xFFDDD6FE)),
                        ),
                        child: Text(
                          user.effectiveTitle,
                          style: TextStyle(
                              color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6D28D9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  // Ban / Freeze notice banner
                  if (user.isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '🚫 Заблокирован бессрочно: ${user.blockReason ?? "Нарушение правил"}',
                          style: TextStyle(
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else if (user.isCurrentlyFrozen)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '❄️ Заморожен до ${user.blockUntil != null ? "${user.blockUntil!.day.toString().padLeft(2, '0')}.${user.blockUntil!.month.toString().padLeft(2, '0')}.${user.blockUntil!.year}" : "срока"}: ${user.blockReason ?? "Нарушение правил"}',
                          style: TextStyle(
                              color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 1. Grant Titles & Perks Button
            Tooltip(
              message: canManage || isSelf
                  ? 'Выдать титул или плюшки 🎁'
                  : 'Недостаточно прав для выдачи титулов этому рангу',
              child: IconButton(
                icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                color: (canManage || isSelf)
                    ? (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED))
                    : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                onPressed: (canManage || isSelf)
                    ? () => AdminUserDialogs.showManageTitlesDialog(context, ref, user)
                    : null,
              ),
            ),
            const SizedBox(width: 6),

            // 2. Role Selector (Strict Hierarchy Protection)
            if (isSelf)
              Tooltip(
                message: 'Ваш текущий ранг (защита от изменения собственной роли)',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullRoleTitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      const SizedBox(width: 4),
                      const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF9F67FF)),
                    ],
                  ),
                ),
              )
            else if (!canManage)
              Tooltip(
                message: 'Ранг равен или выше вашего. Управление недоступно по иерархии.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullRoleTitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF9F67FF).withValues(alpha: 0.4)),
                ),
                child: DropdownButton<String>(
                  value: currentActor.assignableRoles.contains(user.role)
                      ? user.role
                      : currentActor.assignableRoles.first,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF1E1E34) : Colors.white,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9F67FF)),
                  items: currentActor.assignableRoles.map((r) {
                    Color itemColor = isDark ? Colors.white : const Color(0xFF0F172A);
                    if (r == 'admin') itemColor = isDark ? const Color(0xFFFDE047) : const Color(0xFFCA8A04);
                    if (r == 'moderator') itemColor = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);

                    final dummy = UserProfile(
                      id: '',
                      email: '',
                      displayName: '',
                      createdAt: DateTime.now(),
                      role: r,
                    );

                    return DropdownMenuItem(
                      value: r,
                      child: Text(
                        dummy.fullRoleTitle,
                        style: TextStyle(fontSize: 12, color: itemColor, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (newRole) async {
                    if (newRole == null || newRole == user.role) return;
                    final success =
                        await ref.read(adminUsersProvider.notifier).updateRole(user.id, newRole);
                    if (context.mounted) {
                      if (success) {
                        TopNotification.showSuccess(
                          context,
                          'Роль для «${user.displayName}» изменена на $newRole',
                          title: 'Роль обновлена',
                        );
                      } else {
                        TopNotification.showError(
                          context,
                          'Не удалось обновить роль пользователя',
                        );
                      }
                    }
                  },
                ),
              ),
            const SizedBox(width: 10),

            // 3. Block / Freeze Button (Self-Ban Prevention + Hierarchy Protection)
            if (isSelf)
              Tooltip(
                message: 'Вы не можете заблокировать собственный аккаунт (защита от самобана)',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.block_rounded,
                      size: 14, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  label: Text('Блокировка',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                  onPressed: null,
                ),
              )
            else if (!canManage)
              Tooltip(
                message: 'Нельзя блокировать равных по рангу или вышестоящих участников',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.shield_outlined,
                      size: 14, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  label: Text('Защищен',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                  onPressed: null,
                ),
              )
            else if (isRestricted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 15),
                label: const Text('Разблокировать', style: TextStyle(fontSize: 11.5)),
                onPressed: () async {
                  await ref.read(adminUsersProvider.notifier).unblockUser(user.id);
                  if (context.mounted) {
                    TopNotification.showSuccess(
                      context,
                      'Ограничения для ${user.displayName} сняты. Аккаунт активен.',
                      title: 'Разблокировано',
                    );
                  }
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 14),
                label: const Text('Блокировка', style: TextStyle(fontSize: 11.5)),
                onPressed: () => AdminUserDialogs.showBlockFreezeDialog(context, ref, user),
              ),
            const SizedBox(width: 8),

            // 4. Open User Profile in Public View
            Tooltip(
              message: 'Открыть профиль @${user.handle}',
              child: IconButton(
                icon: Icon(Icons.open_in_new_rounded,
                    size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                onPressed: () => context.go('/user/${user.handle}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
