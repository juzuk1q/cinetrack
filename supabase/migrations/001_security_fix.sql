-- ==============================================================================
-- CINETRACK: МИГРАЦИЯ 001 — БЕЗОПАСНОСТЬ БАЗЫ ДАННЫХ И RLS (ЭТАП 1)
-- Файл: supabase/migrations/001_security_fix.sql
-- Идемпотентный скрипт: безопасен для повторного запуска
-- Выполните его в Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. ОЧИСТКА РОЛЕЙ И МИГРАЦИЯ СУЩЕСТВУЮЩИХ ПОЛЬЗОВАТЕЛЕЙ
-- Переводим устаревшие роли (creator, developer, coder) в 'admin'
UPDATE public.profiles
SET role = 'admin'
WHERE role IN ('developer', 'coder', 'creator');

-- Все остальные некорректные роли приводим к базовой роли 'user'
UPDATE public.profiles
SET role = 'user'
WHERE role NOT IN ('user', 'moderator', 'admin');

-- Обновляем CHECK constraint таблицы profiles на строго 3 допустимые роли
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('user', 'moderator', 'admin'));

-- 2. УДАЛЕНИЕ PASSWORD_HASH ИЗ ТАБЛИЦЫ PROFILES
-- Пароли должны храниться ИСКЛЮЧИТЕЛЬНО в защищённой схеме auth.users
ALTER TABLE public.profiles DROP COLUMN IF EXISTS password_hash;

-- Удаляем устаревшие небезопасные RPC-функции смены и проверки паролей
DROP FUNCTION IF EXISTS public.set_user_password(UUID, TEXT);
DROP FUNCTION IF EXISTS public.set_user_password(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_user_password(TEXT, TEXT);

-- 3. ФУНКЦИИ ПРОВЕРКИ ПРАВ ПЕРСОНАЛА (is_admin_or_staff, is_admin)
-- Закрепляем SET search_path = public для защиты от search_path hijacking
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

-- 4. ЗАЩИТА ЭСКАЛАЦИИ ПРИВИЛЕГИЙ (set_user_role, freeze_or_block_user)
CREATE OR REPLACE FUNCTION public.set_user_role(target_user_id UUID, new_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Проверка прав вызывающего (только админы и персонал)
    IF NOT public.is_admin_or_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not authorized to set roles';
    END IF;

    -- Запрет изменения роли самому себе (защита от случайной потери прав единственного админа)
    IF auth.uid() = target_user_id THEN
        RAISE EXCEPTION 'Cannot modify own role';
    END IF;

    -- Валидация новой роли
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
    -- Проверка прав вызывающего
    IF NOT public.is_admin_or_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not staff';
    END IF;

    -- Запрет блокировать или замораживать самого себя
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

-- 5. ТРИГГЕР ЗАЩИТЫ ПОЛЕЙ ПРОФИЛЯ ОТ ПРЯМОГО UPDATE ПОЛЬЗОВАТЕЛЯМИ
-- Обычный пользователь не может изменить свои role, is_blocked, is_frozen, block_reason, block_until
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

-- Обновление триггера регистрации handle_new_user
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

-- 6. ПУБЛИЧНЫЙ VIEW ДЛЯ ЗАЩИТЫ ПЕРСОНАЛЬНЫХ ДАННЫХ И ПРИВАТНЫХ ПРОФИЛЕЙ
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

-- 7. ОБНОВЛЕНИЕ RLS ПОЛИТИК ТАБЛИЦЫ PROFILES
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

-- 8. ОБНОВЛЕНИЕ RLS ПОЛИТИК: КОМНАТЫ (public.rooms)
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

-- 9. ОБНОВЛЕНИЕ RLS ПОЛИТИК: СООБЩЕНИЯ ЧАТА (public.room_messages)
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Все могут читать сообщения" ON public.room_messages;
DROP POLICY IF EXISTS "Все авторизованные могут читать сообщения" ON public.room_messages;
CREATE POLICY "Все могут читать сообщения"
    ON public.room_messages FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Все могут отправлять сообщения" ON public.room_messages;
DROP POLICY IF EXISTS "Авторизованные могут отправлять сообщения" ON public.room_messages;
CREATE POLICY "Авторизованные могут отправлять сообщения"
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

-- 10. ОБНОВЛЕНИЕ RLS ПОЛИТИК: РЕЦЕНЗИИ (public.reviews)
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

-- 11. ОБНОВЛЕНИЕ RLS ПОЛИТИК: КОММЕНТАРИИ К СЕРИЯМ (public.episode_comments)
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

-- 12. ОБНОВЛЕНИЕ RLS ПОЛИТИК: МЕДИАТЕКА (public.media)
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

-- 13. БЕЗОПАСНЫЕ STORAGE ПОЛИТИКИ ДЛЯ АВАТАРОК И БАННЕРОВ (storage.objects)
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
