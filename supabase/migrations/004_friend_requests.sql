-- ============================================================================
-- Migration 004: Friend requests & mutual friendship system
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_sender_receiver UNIQUE(sender_id, receiver_id),
    CONSTRAINT no_self_friendship CHECK (sender_id <> receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_sender ON public.friend_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_receiver ON public.friend_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON public.friend_requests(status);

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Пользователи видят свои заявки в друзья" ON public.friend_requests;
DROP POLICY IF EXISTS "Пользователи видят свои заявки в друзья и принятые заявки" ON public.friend_requests;
CREATE POLICY "Пользователи видят свои заявки в друзья и принятые заявки"
    ON public.friend_requests FOR SELECT
    USING (
        (auth.uid() IS NOT NULL AND (auth.uid() = sender_id OR auth.uid() = receiver_id OR public.is_admin_or_staff(auth.uid())))
        OR status = 'accepted'
    );

DROP POLICY IF EXISTS "Пользователи могут отправлять заявки" ON public.friend_requests;
CREATE POLICY "Пользователи могут отправлять заявки"
    ON public.friend_requests FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = sender_id AND sender_id <> receiver_id
    );

DROP POLICY IF EXISTS "Пользователи могут обновлять статус своих заявок" ON public.friend_requests;
CREATE POLICY "Пользователи могут обновлять статус своих заявок"
    ON public.friend_requests FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = receiver_id OR auth.uid() = sender_id OR public.is_admin_or_staff(auth.uid())
    )
    WITH CHECK (
        auth.uid() = receiver_id OR auth.uid() = sender_id OR public.is_admin_or_staff(auth.uid())
    );

DROP POLICY IF EXISTS "Пользователи могут удалять заявки в друзья" ON public.friend_requests;
CREATE POLICY "Пользователи могут удалять заявки в друзья"
    ON public.friend_requests FOR DELETE
    TO authenticated
    USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id OR public.is_admin_or_staff(auth.uid())
    );

GRANT ALL ON public.friend_requests TO authenticated;
GRANT SELECT ON public.friend_requests TO anon;

-- Enable Realtime for friend_requests
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'friend_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;
