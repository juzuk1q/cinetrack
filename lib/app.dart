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
import 'screens/profile/profile_screen.dart';
import 'screens/rooms/rooms_screen.dart';
import 'screens/rooms/room_detail_screen.dart';
import 'screens/watch/solo_watch_screen.dart';
import 'screens/planner/planner_screen.dart';
import 'screens/stats/stats_screen.dart';

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
        builder: (context, state) => const AccountRestrictedScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/watch',
        name: 'solo-watch',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Фильм';
          final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
          final kinopoiskId = int.tryParse(state.uri.queryParameters['kpId'] ?? '');
          final poster = state.uri.queryParameters['poster'];
          final type = state.uri.queryParameters['type'] ?? 'movie';
          final desc = state.uri.queryParameters['desc'];
          final genres = state.uri.queryParameters['genres'];
          return SoloWatchScreen(
            title: title,
            year: year,
            kinopoiskId: kinopoiskId,
            posterUrl: poster,
            type: type,
            description: desc,
            genres: genres,
          );
        },
      ),
      GoRoute(
        path: '/movie/:id',
        name: 'movie-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final item = state.extra as CatalogItem?;
          return MovieDetailScreen(
            movieId: id,
            initialItem: item,
          );
        },
      ),
      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/media',
        name: 'media',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/catalog',
        name: 'catalog',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/user/:username',
        name: 'user-profile',
        builder: (context, state) {
          final username = state.pathParameters['username'];
          return ProfileScreen(targetUsername: username);
        },
      ),
      GoRoute(
        path: '/rooms',
        name: 'rooms',
        builder: (context, state) => const RoomsScreen(),
      ),
      GoRoute(
        path: '/rooms/:id',
        name: 'room-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RoomDetailScreen(roomId: id);
        },
      ),
      GoRoute(
        path: '/media/add',
        name: 'media-add',
        builder: (context, state) => const AddEditMediaScreen(mediaId: null),
      ),
      GoRoute(
        path: '/media/:id',
        name: 'media-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MovieDetailScreen(movieId: id);
        },
      ),
      GoRoute(
        path: '/media/:id/edit',
        name: 'media-edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AddEditMediaScreen(mediaId: id);
        },
      ),
      GoRoute(
        path: '/planner',
        name: 'planner',
        builder: (context, state) => const PlannerScreen(),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const StatsScreen(),
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
