-- ==============================================================================
-- CINETRACK: ПОЛНЫЙ СКРИПТ НАСТРОЙКИ БАЗЫ ДАННЫХ ДЛЯ SUPABASE (SQL EDITOR)
-- Скопируйте весь текст ниже и выполните его в Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. ТАБЛИЦА ПРОФИЛЕЙ ПОЛЬЗОВАТЕЛЕЙ (public.profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    display_name    TEXT,
    username        TEXT,
    avatar_url      TEXT,
    banner_url      TEXT,
    role            TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin', 'developer', 'coder', 'creator')),
    custom_title    TEXT,
    is_private      BOOLEAN NOT NULL DEFAULT false,
    friends         JSONB NOT NULL DEFAULT '[]'::jsonb,
    unlocked_titles JSONB NOT NULL DEFAULT '["welcome"]'::jsonb,
    is_blocked      BOOLEAN NOT NULL DEFAULT false,
    is_frozen       BOOLEAN NOT NULL DEFAULT false,
    block_reason    TEXT,
    block_until     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Добавляем колонки, если таблица profiles уже существовала ранее
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS banner_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_title TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS friends JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS unlocked_titles JSONB NOT NULL DEFAULT '["welcome"]'::jsonb;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_frozen BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS block_reason TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS block_until TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;

-- Обновление ограничения допустимых ролей (user, moderator, admin, developer, coder, creator)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('user', 'moderator', 'admin', 'developer', 'coder', 'creator'));

-- Индексы для быстрого поиска по username и email
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- Включаем RLS для profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Публичный доступ к чтению профилей" ON public.profiles;
DROP POLICY IF EXISTS "Все авторизованные могут читать профили" ON public.profiles;
CREATE POLICY "Публичный доступ к чтению профилей"
    ON public.profiles FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Пользователи могут обновлять свой профиль или админы" ON public.profiles;
CREATE POLICY "Пользователи могут обновлять свой профиль или админы"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = id OR EXISTS (
            SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'creator', 'developer')
        )
    );

DROP POLICY IF EXISTS "Пользователи могут создавать свой профиль" ON public.profiles;
CREATE POLICY "Пользователи могут создавать свой профиль"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);


-- 2. ТРИГГЕР: АВТОМАТИЧЕСКОЕ СОЗДАНИЕ ПРОФИЛЯ ПРИ РЕГИСТРАЦИИ (auth.users)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    user_handle TEXT;
    user_name TEXT;
    user_avatar TEXT;
    initial_role TEXT;
BEGIN
    -- Юзернейм (логин): сначала username, если нет — префикс почты до @ (без @domain.com)
    user_handle := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''),
        split_part(NEW.email, '@', 1)
    );

    -- Имя для отображения: display_name, либо full_name/name из Google, либо префикс почты
    user_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
        user_handle
    );

    -- Фото профиля (Google OAuth возвращает avatar_url или picture)
    user_avatar := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'avatar_url'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'picture'), '')
    );
    
    -- Все новые пользователи по умолчанию получают обычную роль 'user'
    initial_role := 'user';

    INSERT INTO public.profiles (
        id,
        email,
        display_name,
        username,
        avatar_url,
        role,
        unlocked_titles
    )
    VALUES (
        NEW.id,
        NEW.email,
        user_name,
        user_handle,
        user_avatar,
        initial_role,
        '["welcome"]'::jsonb
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        display_name = COALESCE(public.profiles.display_name, EXCLUDED.display_name),
        username = COALESCE(public.profiles.username, EXCLUDED.username),
        avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Синхронизация уже существующих пользователей из auth.users
INSERT INTO public.profiles (id, email, display_name, username, role, unlocked_titles)
SELECT 
    id,
    COALESCE(email, id::text),
    COALESCE(raw_user_meta_data->>'display_name', split_part(email, '@', 1)),
    COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1)),
    'user' AS role,
    '["welcome"]'::jsonb
FROM auth.users
ON CONFLICT (id) DO NOTHING;


-- 3. ТАБЛИЦА ЛИЧНОЙ МЕДИАТЕКИ (public.media)
CREATE TABLE IF NOT EXISTS public.media (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    type         TEXT NOT NULL CHECK (type IN ('movie', 'series', 'cartoon', 'anime')),
    genres       TEXT[] DEFAULT '{}',
    year         INTEGER,
    director     TEXT,
    actors       TEXT,
    description  TEXT,
    poster_url   TEXT,
    status       TEXT NOT NULL DEFAULT 'want_to_watch'
                     CHECK (status IN ('want_to_watch', 'watching', 'watched')),
    rating       INTEGER CHECK (rating >= 1 AND rating <= 10),
    review       TEXT,
    planned_date DATE,
    watched_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_media_user_id   ON public.media(user_id);
CREATE INDEX IF NOT EXISTS idx_media_status    ON public.media(status);
CREATE INDEX IF NOT EXISTS idx_media_type      ON public.media(type);
CREATE INDEX IF NOT EXISTS idx_media_planned   ON public.media(planned_date);

ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Пользователи видят своё медиа или админы" ON public.media;
CREATE POLICY "Пользователи видят своё медиа или админы"
    ON public.media FOR SELECT
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));

DROP POLICY IF EXISTS "Пользователи могут добавлять медиа" ON public.media;
CREATE POLICY "Пользователи могут добавлять медиа"
    ON public.media FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Пользователи могут обновлять своё медиа" ON public.media;
CREATE POLICY "Пользователи могут обновлять своё медиа"
    ON public.media FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Пользователи могут удалять своё медиа" ON public.media;
CREATE POLICY "Пользователи могут удалять своё медиа"
    ON public.media FOR DELETE
    USING (auth.uid() = user_id);


-- 4. ТАБЛИЦА КОМНАТ СОВМЕСТНОГО ПРОСМОТРА (public.rooms)
CREATE TABLE IF NOT EXISTS public.rooms (
    id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id             TEXT NOT NULL,
    owner_name           TEXT NOT NULL,
    title                TEXT NOT NULL,
    movie_title          TEXT NOT NULL,
    movie_type           TEXT DEFAULT 'movie',
    movie_poster         TEXT,
    movie_year           INTEGER,
    kinopoisk_id         INTEGER,
    status               TEXT DEFAULT 'watching' CHECK (status IN ('preparing', 'watching', 'finished')),
    allow_guest_control  BOOLEAN DEFAULT false,
    participant_count    INTEGER DEFAULT 1,
    video_source_type    TEXT DEFAULT 'none',
    video_url            TEXT,
    current_position     DOUBLE PRECISION DEFAULT 0.0,
    is_playing           BOOLEAN DEFAULT false,
    password             TEXT,
    max_participants     INTEGER,
    scheduled_at         TIMESTAMPTZ DEFAULT NOW(),
    created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Все могут просматривать комнаты" ON public.rooms;
DROP POLICY IF EXISTS "Все авторизованные могут просматривать комнаты" ON public.rooms;
CREATE POLICY "Все могут просматривать комнаты"
    ON public.rooms FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Авторизованные могут создавать комнаты" ON public.rooms;
CREATE POLICY "Авторизованные могут создавать комнаты"
    ON public.rooms FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Участники или админы могут обновлять комнату" ON public.rooms;
CREATE POLICY "Участники или админы могут обновлять комнату"
    ON public.rooms FOR UPDATE
    USING (true);

DROP POLICY IF EXISTS "Владелец или админ может удалять комнату" ON public.rooms;
CREATE POLICY "Владелец или админ может удалять комнату"
    ON public.rooms FOR DELETE
    USING (owner_id = auth.uid()::text OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));


-- 5. ТАБЛИЦА СООБЩЕНИЙ ЧАТА КОМНАТЫ (public.room_messages)
CREATE TABLE IF NOT EXISTS public.room_messages (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id    UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL,
    user_name  TEXT NOT NULL,
    text       TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Все могут читать сообщения" ON public.room_messages;
DROP POLICY IF EXISTS "Все авторизованные могут читать сообщения" ON public.room_messages;
CREATE POLICY "Все могут читать сообщения"
    ON public.room_messages FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Все могут отправлять сообщения" ON public.room_messages;
DROP POLICY IF EXISTS "Авторизованные могут отправлять сообщения" ON public.room_messages;
CREATE POLICY "Все могут отправлять сообщения"
    ON public.room_messages FOR INSERT
    WITH CHECK (true);


-- 6. ТАБЛИЦА РЕЦЕНЗИЙ И ОТЗЫВОВ (public.reviews)
CREATE TABLE IF NOT EXISTS public.reviews (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    kinopoisk_id  INTEGER NOT NULL,
    movie_title   TEXT NOT NULL,
    user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name   TEXT NOT NULL,
    author_title  TEXT DEFAULT 'Зритель CineTrack 🍿',
    rating        DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    type          TEXT NOT NULL DEFAULT 'positive' CHECK (type IN ('positive', 'neutral', 'negative')),
    title         TEXT NOT NULL,
    text          TEXT NOT NULL,
    likes         INTEGER DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reviews_kp_id ON public.reviews(kinopoisk_id);
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Все могут читать рецензии" ON public.reviews;
CREATE POLICY "Все могут читать рецензии"
    ON public.reviews FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Авторизованные могут писать рецензии" ON public.reviews;
CREATE POLICY "Авторизованные могут писать рецензии"
    ON public.reviews FOR INSERT
    TO authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Авторы или админы могут удалять рецензии" ON public.reviews;
CREATE POLICY "Авторы или админы могут удалять рецензии"
    ON public.reviews FOR DELETE
    TO authenticated
    USING (user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ));


-- 7. ТАБЛИЦА КОММЕНТАРИЕВ К СЕРИЯМ И ТАЙМКОДАМ (public.episode_comments)
CREATE TABLE IF NOT EXISTS public.episode_comments (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    kinopoisk_id  INTEGER NOT NULL,
    episode       INTEGER NOT NULL DEFAULT 1,
    season        INTEGER DEFAULT 1,
    timecode      TEXT,
    user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name   TEXT NOT NULL,
    text          TEXT NOT NULL,
    likes         INTEGER DEFAULT 0,
    created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_episode_comments_kp ON public.episode_comments(kinopoisk_id, episode);
ALTER TABLE public.episode_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Все могут читать комментарии к сериям" ON public.episode_comments;
CREATE POLICY "Все могут читать комментарии к сериям"
    ON public.episode_comments FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Авторизованные могут оставлять комментарии к сериям" ON public.episode_comments;
CREATE POLICY "Авторизованные могут оставлять комментарии к сериям"
    ON public.episode_comments FOR INSERT
    TO authenticated
    WITH CHECK (true);


-- 8. ХРАНИЛИЩЕ SUPABASE STORAGE: BUCKETS ДЛЯ АВАТАРОК И БАННЕРОВ
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Политики доступа к Storage (загрузка и просмотр картинок)
DROP POLICY IF EXISTS "Публичный просмотр аватарок и баннеров" ON storage.objects;
CREATE POLICY "Публичный просмотр аватарок и баннеров"
    ON storage.objects FOR SELECT
    USING (bucket_id IN ('avatars', 'banners'));

DROP POLICY IF EXISTS "Авторизованные могут загружать файлы в аватарки и баннеры" ON storage.objects;
CREATE POLICY "Авторизованные могут загружать файлы в аватарки и баннеры"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id IN ('avatars', 'banners'));

DROP POLICY IF EXISTS "Авторизованные могут обновлять свои файлы в storage" ON storage.objects;
CREATE POLICY "Авторизованные могут обновлять свои файлы в storage"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id IN ('avatars', 'banners'));


-- 9. REALTIME: СИНХРОНИЗАЦИЯ КОМНАТ И ЧАТА В РЕАЛЬНОМ ВРЕМЕНИ
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'rooms'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'room_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'reviews'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'episode_comments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.episode_comments;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;


-- 10. ТРИГГЕРЫ ОБНОВЛЕНИЯ updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS media_updated_at ON public.media;
CREATE TRIGGER media_updated_at
    BEFORE UPDATE ON public.media
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;
CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ==============================================================================
-- 11. НАЗНАЧЕНИЕ ПРАВ АДМИНИСТРАТОРА (ВРУЧНУЮ ПО РОЛИ В БД):
-- Чтобы назначить любого пользователя администратором, выполните:
-- UPDATE public.profiles SET role = 'admin' WHERE username = 'ваш_логин';
-- или:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'ваша_почта@example.com';
-- ==============================================================================
