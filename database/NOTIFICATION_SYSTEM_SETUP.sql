-- =====================================================
-- SUPABASE NOTIFICATION SYSTEM SETUP
-- Complete notification system with user-configurable settings
-- =====================================================

-- STEP 1: Enable Required Extensions
-- pg_cron: Schedule recurring jobs in Postgres
-- pg_net: Make HTTP requests from Postgres (call Edge Functions)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- STEP 2: Add notification settings columns to users table
-- This stores per-user notification preferences
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'UTC',
ADD COLUMN IF NOT EXISTS notification_enabled BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS notification_time TIME DEFAULT '09:00:00',
ADD COLUMN IF NOT EXISTS reminder_days INTEGER[] DEFAULT ARRAY[30, 7, 1],
ADD COLUMN IF NOT EXISTS allowed_weekdays TEXT[] DEFAULT ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
ADD COLUMN IF NOT EXISTS last_notification_check TIMESTAMPTZ;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token) WHERE fcm_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_notification_enabled ON public.users(notification_enabled) WHERE notification_enabled = true;

-- STEP 3: Create notification_logs table
-- Track sent notifications to avoid duplicates
CREATE TABLE IF NOT EXISTS public.notification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL, -- 'expiring_30', 'expiring_7', 'expiring_1', 'expired'
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    days_until_expiry INTEGER
);

-- Create indexes for performance (duplicate prevention handled in Edge Function)
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON public.notification_logs(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_doc ON public.notification_logs(user_id, document_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_lookup ON public.notification_logs(user_id, document_id, notification_type, sent_at);

-- STEP 4: Create Edge Function endpoint URL storage
-- Store your Supabase Edge Function URL here
CREATE TABLE IF NOT EXISTS public.system_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert Edge Function URL (UPDATE THIS after deploying your Edge Function)
INSERT INTO public.system_config (key, value) 
VALUES ('edge_function_url', 'https://kxknkjtoqnxxnwmgsdsm.supabase.co/functions/v1/check-expiries')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Insert FCM Server Key (UPDATE THIS with your Firebase Server Key)
INSERT INTO public.system_config (key, value) 
VALUES ('fcm_server_key', 'YOUR_FCM_SERVER_KEY_HERE')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- STEP 5: Schedule pg_cron job
-- Runs every 15 minutes to check for notifications
-- This calls the Edge Function which does the actual work
SELECT cron.schedule(
    'check-document-expiries',           -- Job name
    '*/15 * * * *',                      -- Every 15 minutes (cron format)
    $$
    SELECT
      net.http_post(
          url := (SELECT value FROM public.system_config WHERE key = 'edge_function_url'),
          headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.settings.service_role_key') || '"}'::jsonb,
          body := '{}'::jsonb
      ) as request_id;
    $$
);

-- STEP 6: View scheduled jobs
-- Run this to confirm the job was created
SELECT * FROM cron.job;

-- STEP 7: View job run history (useful for debugging)
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- =====================================================
-- USEFUL QUERIES FOR TESTING
-- =====================================================

-- Check user notification settings
-- SELECT id, email, timezone, notification_time, reminder_days, allowed_weekdays, fcm_token 
-- FROM public.users WHERE notification_enabled = true;

-- Check recent notification logs
-- SELECT nl.*, u.email, d.document_name 
-- FROM public.notification_logs nl
-- JOIN public.users u ON nl.user_id = u.id
-- JOIN public.documents d ON nl.document_id = d.id
-- ORDER BY nl.sent_at DESC LIMIT 20;

-- Manually trigger a test run (for debugging)
-- SELECT
--   net.http_post(
--       url := (SELECT value FROM public.system_config WHERE key = 'edge_function_url'),
--       headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
--       body := '{}'::jsonb
--   );

-- =====================================================
-- CLEANUP (if needed)
-- =====================================================

-- Unschedule the cron job (if you need to remove it)
-- SELECT cron.unschedule('check-document-expiries');

-- Drop notification_logs table
-- DROP TABLE IF EXISTS public.notification_logs CASCADE;
