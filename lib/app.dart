import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'models/catalog_item.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/auth/account_restricted_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/media/add_edit_media_screen.dart';
import 'screens/movie/movie_detail_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/rooms/rooms_screen.dart';
import 'screens/rooms/room_detail_screen.dart';
import 'screens/watch/solo_watch_screen.dart';
import 'screens/planner/planner_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'widgets/animations/app_animations.dart';

class CineTrackApp extends ConsumerWidget {
  const CineTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'CineTrack',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      routerConfig: router,
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authStateProvider);
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final user = authRepo.currentUser;
      final isAuth = user != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isRestrictedRoute = state.matchedLocation == '/restricted';

      // Если пользователь не вошел — перенаправляем на экран авторизации
      if (!isAuth && !isAuthRoute) {
        return '/login';
      }

      // Проверка на заморозку / блокировку аккаунта
      final userProf = ref.read(userProfileProvider).value;
      final isRestricted = userProf?.isRestricted ?? false;
      if (isAuth && isRestricted && !isRestrictedRoute) {
        return '/restricted';
      }
      if (isAuth && !isRestricted && isRestrictedRoute) {
        return '/home';
      }

      // Проверка доступа к панели администратора /admin (только role == admin)
      final isAdminRoute = state.matchedLocation == '/admin';
      final isAdmin = userProf?.isAdmin ?? false;
      if (isAdminRoute && !isAdmin) {
        return '/home';
      }

      // Если пользователь уже вошел и пытается открыть логин/регистрацию — перенаправляем на главную
      if (isAuth && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    refreshListenable: authNotifier,
    routes: [
      GoRoute(
        path: '/restricted',
        name: 'restricted',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const AccountRestrictedScreen(),
        ),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const AdminScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/watch',
        name: 'solo-watch',
        pageBuilder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Фильм';
          final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
          final kinopoiskId = int.tryParse(state.uri.queryParameters['kpId'] ?? '');
          final poster = state.uri.queryParameters['poster'];
          final type = state.uri.queryParameters['type'] ?? 'movie';
          final desc = state.uri.queryParameters['desc'];
          final genres = state.uri.queryParameters['genres'];
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: SoloWatchScreen(
              title: title,
              year: year,
              kinopoiskId: kinopoiskId,
              posterUrl: poster,
              type: type,
              description: desc,
              genres: genres,
            ),
          );
        },
      ),
      GoRoute(
        path: '/movie/:id',
        name: 'movie-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          final item = state.extra as CatalogItem?;
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: MovieDetailScreen(
              movieId: id,
              initialItem: item,
            ),
          );
        },
      ),
      GoRoute(
        path: '/library',
        name: 'library',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const LibraryScreen(),
        ),
      ),
      GoRoute(
        path: '/media',
        name: 'media',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const LibraryScreen(),
        ),
      ),
      GoRoute(
        path: '/catalog',
        name: 'catalog',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const CatalogScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/user/:username',
        name: 'user-profile',
        pageBuilder: (context, state) {
          final username = state.pathParameters['username'];
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: ProfileScreen(targetUsername: username),
          );
        },
      ),
      GoRoute(
        path: '/rooms',
        name: 'rooms',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const RoomsScreen(),
        ),
      ),
      GoRoute(
        path: '/rooms/:id',
        name: 'room-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: RoomDetailScreen(roomId: id),
          );
        },
      ),
      GoRoute(
        path: '/media/add',
        name: 'media-add',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const AddEditMediaScreen(mediaId: null),
        ),
      ),
      GoRoute(
        path: '/media/:id',
        name: 'media-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: MovieDetailScreen(movieId: id),
          );
        },
      ),
      GoRoute(
        path: '/media/:id/edit',
        name: 'media-edit',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return buildSmoothTransitionPage(
            context: context,
            state: state,
            child: AddEditMediaScreen(mediaId: id),
          );
        },
      ),
      GoRoute(
        path: '/planner',
        name: 'planner',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const PlannerScreen(),
        ),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        pageBuilder: (context, state) => buildSmoothTransitionPage(
          context: context,
          state: state,
          child: const StatsScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Страница не найдена: ${state.error}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
