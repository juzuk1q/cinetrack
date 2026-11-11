# CineTrack 🎬

> Полнофункциональное кроссплатформенное веб-приложение для учёта и планирования просмотра фильмов, сериалов и мультфильмов.
> **Стек:** Flutter 3.x (Web) + Supabase (PostgreSQL 15, Auth, Row Level Security, Edge Functions) + Riverpod 2.x + Material 3.

---

## 🚀 Запуск и сборка проекта

### Запуск в режиме разработки с Hot Reload
В папке проекта дважды кликните по:
```text
run_chrome.bat
```
*(Или в терминале: `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`)*

### Сборка для продакшена (Web)
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://xwfixqgmuhzqbfdsiqmt.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## ⚙️ Конфигурация и переменные окружения

Конфигурация Supabase вынесена в `lib/core/env.dart` и читается через `String.fromEnvironment`:
- `SUPABASE_URL` — адрес проекта Supabase
- `SUPABASE_ANON_KEY` — публичный anon-ключ

### ⚡ Supabase Edge Function: `kinopoisk-proxy`
Ключи Kinopoisk удалены из клиентского кода. Все запросы к каталогу проксируются через Edge Function `kinopoisk-proxy` с автоматической ротацией ключей при 402/429 ошибках и белым списком разрешённых эндпоинтов:
1. Задайте секреты в Supabase CLI:
   ```bash
   supabase secrets set KINOPOISK_API_KEYS="ваш_ключ_1,ваш_ключ_2"
   ```
2. Задеплойте функцию:
   ```bash
   supabase functions deploy kinopoisk-proxy
   ```

---

## 🗄️ Настройка базы данных в Supabase

1. Откройте панель управления [supabase.com](https://supabase.com) → выберите проект `cinetrack`.
2. Перейдите в **SQL Editor** (слева в меню).
3. Примените миграцию безопасности из [`supabase/migrations/001_security_fix.sql`](./supabase/migrations/001_security_fix.sql) (или базовый [`supabase_setup.sql`](./supabase_setup.sql)) и нажмите **Run** (зелёная кнопка ▶).
4. Перейдите в **Authentication → Providers → Email** и отключите флаг **"Confirm email"** (чтобы можно было сразу входить без подтверждения почты).

---

## 💡 Архитектура и структура проекта

Проект построен по слоистой архитектуре (Repository Pattern + Riverpod State Management):

```text
lib/
├── main.dart                     # Инициализация Supabase через Env + Scope провайдеров
├── app.dart                      # GoRouter с защищёнными маршрутами + локализация (ru)
├── core/
│   ├── env.dart                  # Чтение SUPABASE_URL и SUPABASE_ANON_KEY из окружения
│   ├── supabase_client.dart      # Singleton-клиент Supabase
│   ├── theme.dart                # Тёмная кинотеатральная тема (Material 3)
│   └── constants.dart            # Справочники жанров, типов медиа, статусов
├── models/
│   ├── user_profile.dart         # Профиль пользователя с ролевой моделью (user/moderator/admin)
│   ├── catalog_item.dart         # Элемент каталога Kinopoisk / Lordfilm
│   ├── movie_review.dart         # Рецензии пользователей с оценками 1-10
│   ├── episode_comment.dart      # Комментарии к сериям с интерактивными таймкодами
│   ├── media_item.dart           # DTO сущности медиа библиотеки
│   └── series_season.dart        # Структура сезонов и серий
├── repositories/
│   ├── auth_repository.dart      # Вход, регистрация, Supabase Auth
│   ├── review_repository.dart    # Рецензии и комментарии к сериям (Supabase RLS)
│   ├── media_repository.dart     # CRUD медиатеки пользователя
│   └── stats_repository.dart     # Агрегация аналитики для дашборда
├── providers/
│   ├── auth_provider.dart        # Сессия, профиль, проверка прав администратора
│   ├── media_provider.dart       # Провайдеры фильтрации и коллекций
│   └── stats_provider.dart       # Реактивные вычисления для дашборда
├── services/
│   └── kinopoisk_service.dart    # Клиент прокси Kinopoisk через Edge Function
└── screens/
    ├── auth/                     # Вход, регистрация, восстановление пароля
    ├── home/                     # Главный дашборд
    ├── movie/                    # Карточка фильма/сериала с рецензиями
    ├── watch/                    # Видеоплеер с комментариями к сериям и таймкодами
    ├── catalog/                  # Каталог популярных фильмов и сериалов
    ├── rooms/                    # Комнаты совместного просмотра
    ├── admin/                    # Панель управления пользователями и ролями (admin-only)
    ├── media/                    # Библиотека пользователя
    ├── planner/                  # Календарь запланированных просмотров
    └── stats/                    # Статистика и графики просмотров
```
