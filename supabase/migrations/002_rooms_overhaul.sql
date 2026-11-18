-- ==============================================================================
-- CINETRACK: МИГРАЦИЯ 002 — КОМНАТЫ СОВМЕСТНОГО ПРОСМОТРА (ЭТАП 4)
-- Файл: supabase/migrations/002_rooms_overhaul.sql
-- Идемпотентный скрипт: безопасен для повторного запуска
-- Выполните его в Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. ДОБАВЛЕНИЕ НЕДОСТАЮЩИХ КОЛОНОК В ТАБЛИЦУ rooms
-- (если таблица уже существует, добавляем колонки через ADD COLUMN IF NOT EXISTS)

-- Базовые поля
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'Комната';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS movie_title TEXT NOT NULL DEFAULT 'Источник не выбран';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS movie_type TEXT NOT NULL DEFAULT 'movie';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS movie_poster TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS movie_year INT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS kinopoisk_id INT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'watching';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS owner_name TEXT NOT NULL DEFAULT 'Организатор';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS owner_id TEXT; -- auth.uid()::text
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS allow_guest_control BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS participant_count INT NOT NULL DEFAULT 1;

-- Видеоисточник
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS video_source_type TEXT NOT NULL DEFAULT 'none';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS video_url TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS video_file_name TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS current_position DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS is_playing BOOLEAN NOT NULL DEFAULT FALSE;

-- Пароль (SHA-256 хеш, НЕ открытый текст)
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS max_participants INT;

-- Участники и контроллеры (JSONB массивы)
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS participants JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS allowed_controllers JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Метки времени
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Если есть старая колонка password (открытый текст) — удаляем
-- (данные уже скомпрометированы, лучше сбросить)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'rooms' AND column_name = 'password'
    ) THEN
        -- Мигрируем существующие пароли в хеш (sha256)
        UPDATE public.rooms
        SET password_hash = encode(sha256(convert_to(password, 'UTF8')), 'hex')
        WHERE password IS NOT NULL AND password != '' AND (password_hash IS NULL OR password_hash = '');

        ALTER TABLE public.rooms DROP COLUMN password;
    END IF;
END;
$$;

-- 2. ДОБАВЛЕНИЕ НЕДОСТАЮЩИХ КОЛОНОК В ТАБЛИЦУ room_messages

ALTER TABLE public.room_messages ADD COLUMN IF NOT EXISTS user_name TEXT NOT NULL DEFAULT 'Зритель';
ALTER TABLE public.room_messages ADD COLUMN IF NOT EXISTS text TEXT NOT NULL DEFAULT '';
ALTER TABLE public.room_messages ADD COLUMN IF NOT EXISTS user_id TEXT; -- auth.uid()::text
ALTER TABLE public.room_messages ADD COLUMN IF NOT EXISTS room_id TEXT; -- ссылка на rooms.id
ALTER TABLE public.room_messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 3. ИНДЕКСЫ ДЛЯ ОПТИМИЗАЦИИ ЗАПРОСОВ

CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);
CREATE INDEX IF NOT EXISTS idx_rooms_owner_id ON public.rooms(owner_id);
CREATE INDEX IF NOT EXISTS idx_room_messages_room_id ON public.room_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_room_messages_created_at ON public.room_messages(created_at);

-- 4. ТРИГГЕР AUTO-UPDATE updated_at

CREATE OR REPLACE FUNCTION public.update_rooms_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_rooms_updated_at ON public.rooms;
CREATE TRIGGER tr_rooms_updated_at
    BEFORE UPDATE ON public.rooms
    FOR EACH ROW
    EXECUTE FUNCTION public.update_rooms_updated_at();

-- 5. RPC ДЛЯ ПРОВЕРКИ ПАРОЛЯ КОМНАТЫ (сравнение хешей на сервере)

CREATE OR REPLACE FUNCTION public.verify_room_password(
    target_room_id TEXT,
    attempt_password TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    stored_hash TEXT;
    attempt_hash TEXT;
BEGIN
    SELECT password_hash INTO stored_hash
    FROM public.rooms
    WHERE id = target_room_id;

    -- Если комнаты нет — false
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Если пароль не задан — всегда true
    IF stored_hash IS NULL OR stored_hash = '' THEN
        RETURN TRUE;
    END IF;

    attempt_hash := encode(sha256(convert_to(attempt_password, 'UTF8')), 'hex');
    RETURN stored_hash = attempt_hash;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.verify_room_password(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_room_password(TEXT, TEXT) TO authenticated;

-- 6. RPC ДЛЯ СОЗДАНИЯ КОМНАТЫ С ХЕШИРОВАНИЕМ ПАРОЛЯ

CREATE OR REPLACE FUNCTION public.create_room_with_password(
    p_id TEXT,
    p_title TEXT,
    p_owner_name TEXT,
    p_owner_id TEXT,
    p_password TEXT DEFAULT NULL,
    p_max_participants INT DEFAULT NULL,
    p_movie_title TEXT DEFAULT 'Источник не выбран',
    p_movie_type TEXT DEFAULT 'movie',
    p_movie_poster TEXT DEFAULT NULL,
    p_movie_year INT DEFAULT NULL,
    p_kinopoisk_id INT DEFAULT NULL,
    p_video_source_type TEXT DEFAULT 'none',
    p_video_url TEXT DEFAULT NULL,
    p_scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    p_allow_guest_control BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
    hashed_pwd TEXT;
    result JSONB;
BEGIN
    -- Хешируем пароль если задан
    IF p_password IS NOT NULL AND p_password != '' THEN
        hashed_pwd := encode(sha256(convert_to(p_password, 'UTF8')), 'hex');
    END IF;

    INSERT INTO public.rooms (
        id, title, movie_title, movie_type, movie_poster, movie_year,
        kinopoisk_id, status, scheduled_at, owner_name, owner_id,
        allow_guest_control, participant_count, video_source_type, video_url,
        password_hash, max_participants, participants
    ) VALUES (
        p_id, p_title, p_movie_title, p_movie_type, p_movie_poster, p_movie_year,
        p_kinopoisk_id, 'watching', p_scheduled_at, p_owner_name, p_owner_id,
        p_allow_guest_control, 1, p_video_source_type, p_video_url,
        hashed_pwd, p_max_participants,
        jsonb_build_array(jsonb_build_object('id', p_owner_id, 'name', p_owner_name))
    )
    RETURNING to_jsonb(rooms.*) INTO result;

    -- Добавляем поле has_password (для клиента)
    result := result || jsonb_build_object('has_password', hashed_pwd IS NOT NULL);

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.create_room_with_password(TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, INT, INT, TEXT, TEXT, TIMESTAMPTZ, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_room_with_password(TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT, INT, INT, TEXT, TEXT, TIMESTAMPTZ, BOOLEAN) TO authenticated;

-- 7. ВКЛЮЧЕНИЕ REALTIME ДЛЯ ТАБЛИЦ rooms И room_messages

ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
