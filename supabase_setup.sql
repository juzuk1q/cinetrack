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
    role            TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin')),
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

-- Колонки для случая, если таблица создавалась ранее
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

-- Удаление устаревшей колонки паролей (пароли живут только в auth.users)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS password_hash;

-- Обновление ограничения допустимых ролей (строго: user, moderator, admin)
UPDATE public.profiles SET role = 'admin' WHERE role IN ('developer', 'coder', 'creator');
UPDATE public.profiles SET role = 'user' WHERE role NOT IN ('user', 'moderator', 'admin');

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('user', 'moderator', 'admin'));

-- Индексы для быстрого поиска и уникальности юзернейма
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
DROP INDEX IF EXISTS idx_profiles_username;
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_unique ON public.profiles(LOWER(username));

-- Функции проверки прав персонала
CREATE OR REPLACE FUNCTION public.is_admin_or_staff(check_uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF check_uid IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = check_uid AND role IN ('admin', 'moderator')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_admin(check_uid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF check_uid IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = check_uid AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Безопасный поиск email по логину (для входа по логину или email)
CREATE OR REPLACE FUNCTION public.find_user_email_by_login(user_login TEXT)
RETURNS TEXT AS $$
DECLARE
    found_email TEXT;
    clean_login TEXT;
BEGIN
    IF user_login IS NULL OR TRIM(user_login) = '' THEN
        RETURN NULL;
    END IF;

    clean_login := LOWER(TRIM(REPLACE(user_login, '@', '')));

    SELECT email INTO found_email
    FROM public.profiles
    WHERE LOWER(profiles.username) = clean_login
       OR LOWER(profiles.email) = LOWER(TRIM(user_login))
    LIMIT 1;

    RETURN found_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.find_user_email_by_login(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_user_email_by_login(TEXT) TO anon, authenticated;

-- Защищенные RPC функции: смена роли и блокировка
CREATE OR REPLACE FUNCTION public.set_user_role(target_user_id UUID, new_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT public.is_admin_or_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not authorized to set roles';
    END IF;

    IF auth.uid() = target_user_id THEN
        RAISE EXCEPTION 'Cannot modify own role';
    END IF;

    IF new_role NOT IN ('user', 'moderator', 'admin') THEN
        RAISE EXCEPTION 'Invalid role: %', new_role;
    END IF;

    UPDATE public.profiles
    SET role = new_role,
        updated_at = NOW()
    WHERE id = target_user_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_user_role(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.freeze_or_block_user(
    target_user_id UUID,
    set_frozen BOOLEAN,
    set_blocked BOOLEAN,
    reason TEXT,
    freeze_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT public.is_admin_or_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not staff';
    END IF;

    IF auth.uid() = target_user_id THEN
        RAISE EXCEPTION 'Cannot freeze or block self';
    END IF;

    UPDATE public.profiles
    SET is_frozen = COALESCE(set_frozen, false),
        is_blocked = COALESCE(set_blocked, false),
        block_reason = reason,
        block_until = freeze_until,
        updated_at = NOW()
    WHERE id = target_user_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.freeze_or_block_user(UUID, BOOLEAN, BOOLEAN, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.freeze_or_block_user(UUID, BOOLEAN, BOOLEAN, TEXT, TIMESTAMPTZ) TO authenticated;

-- Удаление старых небезопасных RPC функций
DROP FUNCTION IF EXISTS public.set_user_password(UUID, TEXT);
DROP FUNCTION IF EXISTS public.set_user_password(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_user_password(TEXT, TEXT);

-- Триггер защиты привилегированных полей от прямого UPDATE
CREATE OR REPLACE FUNCTION public.protect_profile_privileged_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin_or_staff(auth.uid()) THEN
        NEW.role := OLD.role;
        NEW.is_blocked := OLD.is_blocked;
        NEW.is_frozen := OLD.is_frozen;
        NEW.block_reason := OLD.block_reason;
        NEW.block_until := OLD.block_until;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS tr_protect_profile_privileged_fields ON public.profiles;
CREATE TRIGGER tr_protect_profile_privileged_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_privileged_fields();

-- Публичный View профилей с маскированием email и приватных данных
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT 
    p.id,
    p.username,
    p.avatar_url,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.display_name
        ELSE p.username 
    END AS display_name,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.banner_url
        ELSE NULL 
    END AS banner_url,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.role
        ELSE 'user' 
    END AS role,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.custom_title
        ELSE NULL 
    END AS custom_title,
    p.is_private,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) THEN p.email
        ELSE NULL 
    END AS email,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.friends
        ELSE '[]'::jsonb 
    END AS friends,
    CASE 
        WHEN auth.uid() = p.id OR public.is_admin_or_staff(auth.uid()) OR p.is_private = false THEN p.unlocked_titles
        ELSE '[]'::jsonb 
    END AS unlocked_titles,
    p.created_at,
    p.updated_at
FROM public.profiles p;

GRANT SELECT ON public.public_profiles TO anon, authenticated;

-- RLS для profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Публичный доступ к чтению профилей" ON public.profiles;
DROP POLICY IF EXISTS "Все авторизованные могут читать профили" ON public.profiles;
DROP POLICY IF EXISTS "Пользователи видят свой профиль или админы" ON public.profiles;
DROP POLICY IF EXISTS "Профиль доступен владельцу, персоналу или публично" ON public.profiles;

CREATE POLICY "Профиль доступен владельцу, персоналу или публично"
    ON public.profiles FOR SELECT
    USING (
        auth.uid() = id 
        OR public.is_admin_or_staff(auth.uid())
        OR is_private = false
    );

DROP POLICY IF EXISTS "Пользователи могут обновлять свой профиль или админы" ON public.profiles;
CREATE POLICY "Пользователи могут обновлять свой профиль или админы"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = id OR public.is_admin_or_staff(auth.uid())
    )
    WITH CHECK (
        auth.uid() = id OR public.is_admin_or_staff(auth.uid())
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
BEGIN
    user_handle := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''),
        split_part(NEW.email, '@', 1)
    );

    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE LOWER(profiles.username) = LOWER(user_handle) AND profiles.id <> NEW.id
    ) THEN
        user_handle := user_handle || '_' || substr(NEW.id::text, 1, 4);
    END IF;

    user_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
        user_handle
    );

    user_avatar := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'avatar_url'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'picture'), '')
    );

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
        'user',
        '["welcome"]'::jsonb
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        display_name = COALESCE(public.profiles.display_name, EXCLUDED.display_name),
        username = COALESCE(public.profiles.username, EXCLUDED.username),
        avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
    TO authenticated
    USING (
        auth.uid() = user_id 
        OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Пользователи могут добавлять медиа" ON public.media;
CREATE POLICY "Пользователи могут добавлять медиа"
    ON public.media FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id 
        OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Пользователи могут обновлять своё медиа" ON public.media;
CREATE POLICY "Пользователи могут обновлять своё медиа"
    ON public.media FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = user_id 
        OR public.is_admin_or_staff(auth.uid())
    )
    WITH CHECK (
        auth.uid() = user_id 
        OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Пользователи могут удалять своё медиа" ON public.media;
CREATE POLICY "Пользователи могут удалять своё медиа"
    ON public.media FOR DELETE
    TO authenticated
    USING (
        auth.uid() = user_id 
        OR public.is_admin_or_staff(auth.uid())
    );


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
    TO authenticated
    WITH CHECK (owner_id = auth.uid()::text);

DROP POLICY IF EXISTS "Участники или админы могут обновлять комнату" ON public.rooms;
DROP POLICY IF EXISTS "Владелец или админ может обновлять комнату" ON public.rooms;
CREATE POLICY "Владелец или админ может обновлять комнату"
    ON public.rooms FOR UPDATE
    TO authenticated
    USING (
        owner_id = auth.uid()::text 
        OR public.is_admin_or_staff(auth.uid())
        OR allow_guest_control = true
    )
    WITH CHECK (
        owner_id = auth.uid()::text 
        OR public.is_admin_or_staff(auth.uid())
        OR allow_guest_control = true
    );

DROP POLICY IF EXISTS "Владелец или админ может удалять комнату" ON public.rooms;
CREATE POLICY "Владелец или админ может удалять комнату"
    ON public.rooms FOR DELETE
    TO authenticated
    USING (
        owner_id = auth.uid()::text 
        OR public.is_admin_or_staff(auth.uid())
    );


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
    TO authenticated
    WITH CHECK (user_id = auth.uid()::text);

DROP POLICY IF EXISTS "Авторы или админы могут удалять сообщения" ON public.room_messages;
CREATE POLICY "Авторы или админы могут удалять сообщения"
    ON public.room_messages FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid()::text 
        OR public.is_admin_or_staff(auth.uid())
    );


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
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Авторы или админы могут обновлять рецензии" ON public.reviews;
CREATE POLICY "Авторы или админы могут обновлять рецензии"
    ON public.reviews FOR UPDATE
    TO authenticated
    USING (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    )
    WITH CHECK (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Авторы или админы могут удалять рецензии" ON public.reviews;
CREATE POLICY "Авторы или админы могут удалять рецензии"
    ON public.reviews FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    );


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
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Авторы или админы могут обновлять комментарии к сериям" ON public.episode_comments;
CREATE POLICY "Авторы или админы могут обновлять комментарии к сериям"
    ON public.episode_comments FOR UPDATE
    TO authenticated
    USING (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    )
    WITH CHECK (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Авторы или админы могут удалять комментарии к сериям" ON public.episode_comments;
CREATE POLICY "Авторы или админы могут удалять комментарии к сериям"
    ON public.episode_comments FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid() 
        OR public.is_admin_or_staff(auth.uid())
    );


-- 8. ХРАНИЛИЩЕ SUPABASE STORAGE: BUCKETS ДЛЯ АВАТАРОК И БАННЕРОВ
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Публичный просмотр аватарок и баннеров" ON storage.objects;
DROP POLICY IF EXISTS "Авторизованные могут загружать файлы в аватарки и баннеры" ON storage.objects;
DROP POLICY IF EXISTS "Авторизованные могут обновлять свои файлы в storage" ON storage.objects;
DROP POLICY IF EXISTS "Пользователи могут загружать файлы только в свою папку" ON storage.objects;
DROP POLICY IF EXISTS "Пользователи могут обновлять только свои файлы" ON storage.objects;
DROP POLICY IF EXISTS "Пользователи могут удалять только свои файлы" ON storage.objects;

CREATE POLICY "Публичный просмотр аватарок и баннеров"
    ON storage.objects FOR SELECT
    USING (bucket_id IN ('avatars', 'banners'));

CREATE POLICY "Пользователи могут загружать файлы только в свою папку"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id IN ('avatars', 'banners') 
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR name LIKE (auth.uid()::text || '/%')
        )
    );

CREATE POLICY "Пользователи могут обновлять только свои файлы"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id IN ('avatars', 'banners') 
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR name LIKE (auth.uid()::text || '/%')
            OR owner::text = auth.uid()::text
        )
    )
    WITH CHECK (
        bucket_id IN ('avatars', 'banners') 
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR name LIKE (auth.uid()::text || '/%')
        )
    );

CREATE POLICY "Пользователи могут удалять только свои файлы"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id IN ('avatars', 'banners') 
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR name LIKE (auth.uid()::text || '/%')
            OR owner::text = auth.uid()::text
            OR public.is_admin_or_staff(auth.uid())
        )
    );


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
