-- ============================================================
-- CineTrack — Supabase SQL Setup
-- Запустите этот файл в SQL Editor вашего проекта Supabase
-- ============================================================

-- 1. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT NOT NULL,
    display_name TEXT,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Пользователи видят только свой профиль"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Пользователи могут обновлять свой профиль"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Пользователи могут создавать свой профиль"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 2. TRIGGER: auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. MEDIA TABLE
CREATE TABLE IF NOT EXISTS public.media (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id      UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    type         TEXT NOT NULL CHECK (type IN ('movie', 'series', 'cartoon')),
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

CREATE POLICY "Пользователи видят только своё медиа"
    ON public.media FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Пользователи могут добавлять медиа"
    ON public.media FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Пользователи могут обновлять своё медиа"
    ON public.media FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Пользователи могут удалять своё медиа"
    ON public.media FOR DELETE
    USING (auth.uid() = user_id);

-- 4. updated_at auto-update trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER media_updated_at
    BEFORE UPDATE ON public.media
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- 5. ROOMS (Комнаты совместного просмотра)
CREATE TABLE IF NOT EXISTS public.rooms (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id     UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    movie_title  TEXT NOT NULL,
    movie_type   TEXT DEFAULT 'movie',
    movie_poster TEXT,
    movie_year   INTEGER,
    status       TEXT DEFAULT 'preparing' CHECK (status IN ('preparing', 'watching', 'finished')),
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    stream_url   TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Все авторизованные могут просматривать комнаты"
    ON public.rooms FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Авторизованные могут создавать комнаты"
    ON public.rooms FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Владелец может обновлять комнату"
    ON public.rooms FOR UPDATE
    TO authenticated
    USING (auth.uid() = owner_id);

CREATE POLICY "Владелец может удалять комнату"
    ON public.rooms FOR DELETE
    TO authenticated
    USING (auth.uid() = owner_id);

-- 6. ROOM MESSAGES (Чат комнаты)
CREATE TABLE IF NOT EXISTS public.room_messages (
    id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id    UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name  TEXT NOT NULL,
    text       TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Все участники могут читать сообщения"
    ON public.room_messages FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Авторизованные могут писать в чат"
    ON public.room_messages FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);
