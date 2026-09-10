-- =====================================================
-- SIMPLE NOTIFICATION CHECK - RUN EACH QUERY ONE BY ONE
-- Copy and run each section separately in Supabase SQL Editor
-- =====================================================

-- ========== STEP 1: Check if pg_cron is enabled ==========
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
-- ✅ Should return 1 row if enabled
-- ❌ If empty, pg_cron is not installed (contact Supabase support)


-- ========== STEP 2: Check if cron job is scheduled ==========
SELECT * FROM cron.job;
-- ✅ Should show jobid, schedule, command for 'check-document-expiries'
-- ❌ If empty, the cron job is NOT scheduled (need to schedule it)


-- ========== STEP 3: Check recent cron runs ==========
SELECT 
  jobid,
  runid,
  status,
  start_time,
  end_time
FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 10;
-- ✅ Should show runs every 15 minutes with status 'succeeded'
-- ❌ If empty, job never ran
-- ❌ If status = 'failed', check return_message


-- ========== STEP 4: Check your notification settings ==========
SELECT 
  email,
  notification_enabled,
  notification_time,
  timezone,
  fcm_token IS NOT NULL as has_fcm_token
FROM users 
WHERE email = 'YOUR_EMAIL_HERE';
-- Replace YOUR_EMAIL_HERE with your actual email
-- ✅ notification_enabled should be true
-- ✅ has_fcm_token should be true


-- ========== STEP 5: Check Edge Function URL ==========
SELECT * FROM system_config WHERE key = 'edge_function_url';
-- ✅ Should show: https://kxknkjtoqnxxnwmgsdsm.supabase.co/functions/v1/check-expiries


-- ========== STEP 6: Check FCM service account ==========
SELECT 
  key,
  LEFT(value, 100) as value_preview
FROM system_config 
WHERE key = 'fcm_server_key';
-- ✅ Should show Firebase service account JSON (starts with {"type":"service_account"...)
-- ❌ If shows 'YOUR_FCM_SERVER_KEY_HERE', you need to add real key


-- ========== STEP 7: Check documents with upcoming expiry ==========
SELECT 
  document_name,
  document_type,
  expiry_date,
  (expiry_date - CURRENT_DATE) as days_until_expiry
FROM documents
WHERE user_id = (SELECT id FROM users WHERE email = 'YOUR_EMAIL_HERE')
  AND expiry_date IS NOT NULL
ORDER BY expiry_date ASC;
-- Replace YOUR_EMAIL_HERE with your actual email
-- ✅ Should show your documents with days_until_expiry
-- Example: If days_until_expiry = 7 and reminder_days includes 7, notification will be sent


-- ========== STEP 8: Check current time vs notification time ==========
SELECT 
  NOW() AT TIME ZONE 'UTC' as utc_now,
  NOW() AT TIME ZONE 'Africa/Accra' as ghana_now,
  (SELECT notification_time FROM users WHERE email = 'YOUR_EMAIL_HERE') as your_notification_time,
  EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'Africa/Accra')) as current_hour,
  EXTRACT(MINUTE FROM (NOW() AT TIME ZONE 'Africa/Accra')) as current_minute;
-- Replace YOUR_EMAIL_HERE with your actual email
-- Check if current time is close to your notification_time


-- ========== STEP 9: Check notification logs ==========
SELECT 
  sent_at,
  notification_type,
  days_until_expiry
FROM notification_logs
WHERE user_id = (SELECT id FROM users WHERE email = 'YOUR_EMAIL_HERE')
ORDER BY sent_at DESC
LIMIT 10;
-- Replace YOUR_EMAIL_HERE with your actual email
-- ✅ If notifications were sent, they appear here
-- ❌ If empty, no notifications sent yet
