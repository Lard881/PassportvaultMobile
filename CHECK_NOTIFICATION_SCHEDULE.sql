-- =====================================================
-- CHECK AUTOMATIC NOTIFICATION SCHEDULE
-- Run this in Supabase SQL Editor
-- =====================================================

-- STEP 1: Check if pg_cron extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
-- Expected: Should return 1 row if enabled

-- STEP 2: Check if pg_net extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';
-- Expected: Should return 1 row if enabled

-- STEP 3: Check scheduled cron jobs
SELECT * FROM cron.job;
-- Expected: Should show 'check-document-expiries' job running every 15 minutes

-- STEP 4: Check recent cron job runs
SELECT 
  jobid,
  runid,
  status,
  start_time,
  end_time,
  return_message
FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 20;
-- Expected: Shows recent runs with status (succeeded/failed)

-- STEP 5: Check Edge Function URL in system_config
SELECT * FROM public.system_config WHERE key = 'edge_function_url';
-- Expected: https://kxknkjtoqnxxnwmgsdsm.supabase.co/functions/v1/check-expiries

-- STEP 6: Check FCM service account in system_config
SELECT 
  key,
  LEFT(value, 50) || '...' as value_preview,
  updated_at
FROM public.system_config 
WHERE key = 'fcm_server_key';
-- Expected: Should show Firebase service account JSON (first 50 chars)

-- STEP 7: Check users with notifications enabled
SELECT 
  email,
  notification_enabled,
  notification_time,
  reminder_days,
  allowed_weekdays,
  timezone,
  LEFT(fcm_token, 30) || '...' as fcm_token_preview,
  last_notification_check
FROM public.users 
WHERE notification_enabled = true;
-- Expected: Your email with notification settings

-- STEP 8: Check documents with upcoming expiry
SELECT 
  u.email,
  d.document_name,
  d.document_type,
  d.expiry_date,
  (d.expiry_date - CURRENT_DATE) as days_until_expiry
FROM public.documents d
JOIN public.users u ON d.user_id = u.id
WHERE d.expiry_date IS NOT NULL
  AND d.expiry_date >= CURRENT_DATE
ORDER BY d.expiry_date ASC
LIMIT 20;
-- Expected: Your documents with days until expiry

-- STEP 9: Check notification logs (if any notifications sent)
SELECT 
  nl.sent_at,
  u.email,
  d.document_name,
  nl.notification_type,
  nl.days_until_expiry
FROM public.notification_logs nl
JOIN public.users u ON nl.user_id = u.id
JOIN public.documents d ON nl.document_id = d.id
ORDER BY nl.sent_at DESC
LIMIT 20;
-- Expected: List of sent notifications (empty if none sent yet)

-- STEP 10: Check current time in your timezone
SELECT 
  NOW() as utc_time,
  NOW() AT TIME ZONE 'Africa/Accra' as ghana_time,
  EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'Africa/Accra')) as current_hour_ghana,
  EXTRACT(MINUTE FROM (NOW() AT TIME ZONE 'Africa/Accra')) as current_minute_ghana;
-- Expected: Shows current time in UTC and Ghana timezone

-- =====================================================
-- DIAGNOSTIC RESULTS
-- =====================================================

-- If cron.job is EMPTY:
-- ❌ Cron job NOT scheduled - Run NOTIFICATION_SYSTEM_SETUP.sql

-- If cron.job_run_details is EMPTY:
-- ❌ Cron job never ran - Check if service_role_key is configured

-- If job_run_details shows FAILED:
-- ❌ Edge function errors - Check edge function logs

-- If job_run_details shows SUCCEEDED but no notifications:
-- ✅ System working, but no matching documents/times

-- =====================================================
-- MANUAL TEST (if cron not working)
-- =====================================================

-- Manually trigger edge function (replace YOUR_SERVICE_ROLE_KEY)
/*
SELECT
  net.http_post(
      url := 'https://kxknkjtoqnxxnwmgsdsm.supabase.co/functions/v1/check-expiries',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
      body := '{}'::jsonb
  ) as request_id;
*/

-- Then check edge function logs in Supabase Dashboard:
-- Dashboard → Edge Functions → check-expiries → Logs
