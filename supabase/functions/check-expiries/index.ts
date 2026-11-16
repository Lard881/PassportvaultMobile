// Supabase Edge Function: check-expiries
// Sends FCM push notifications for expiring documents
// Triggered by pg_cron every 15 minutes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface Document {
  id: string;
  document_name: string;
  document_type: string;
  expiry_date: string;
}

interface User {
  id: string;
  fcm_token: string;
  notification_time: string; // HH:MM:SS format
  timezone: string;
  reminder_days: number[];
  allowed_weekdays: string[];
}

interface FCMCredentials {
  project_id: string;
  private_key: string;
  client_email: string;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('[Edge Function] check-expiries started');

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get FCM credentials from system_config
    const { data: configData, error: configError } = await supabase
      .from('system_config')
      .select('key, value')
      .in('key', ['fcm_server_key']);

    if (configError) {
      console.error('[Edge Function] Config error:', configError);
      throw configError;
    }

    const fcmConfig = configData?.find(c => c.key === 'fcm_server_key');
    if (!fcmConfig) {
      throw new Error('FCM credentials not found in system_config');
    }

    const fcmCredentials: FCMCredentials = JSON.parse(fcmConfig.value);

    // Get current UTC time
    const now = new Date();
    console.log('[Edge Function] Current UTC time:', now.toISOString());

    // Get all users with notifications enabled
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, fcm_token, notification_time, timezone, reminder_days, allowed_weekdays')
      .eq('notification_enabled', true)
      .not('fcm_token', 'is', null);

    if (usersError) {
      console.error('[Edge Function] Users error:', usersError);
      throw usersError;
    }

    console.log(`[Edge Function] Found ${users?.length || 0} users with notifications enabled`);

    let totalNotificationsSent = 0;

    // Process each user
    for (const user of users || []) {
      try {
        // Convert current UTC time to user's timezone
        const userTime = convertToTimezone(now, user.timezone);
        const userHour = userTime.getUTCHours();
        const userMinute = userTime.getUTCMinutes();
        const userDayOfWeek = getDayOfWeek(userTime).toLowerCase();

        // Parse notification_time (format: "09:00:00")
        const [targetHour, targetMinute] = user.notification_time.split(':').map(Number);
        if (
          !Number.isInteger(targetHour) ||
          targetHour < 0 ||
          targetHour > 23 ||
          !Number.isInteger(targetMinute) ||
          targetMinute < 0 ||
          targetMinute > 59
        ) {
          console.error('[Edge Function] Skipping user with invalid notification time');
          continue;
        }

        // FIX: Find nearest cron run (runs at :00, :15, :30, :45)
        // Calculate which 15-minute window we're currently in
        const currentMinuteWindow = Math.floor(userMinute / 15) * 15; // 0, 15, 30, or 45

        // Check if user's target time falls within current 15-minute window
        // Allow 15-minute window: if target is 09:50, check if we're in 09:45-09:59 window
        const targetMinuteWindow = Math.floor(targetMinute / 15) * 15;

        const isTimeMatch =
          userHour === targetHour &&
          currentMinuteWindow === targetMinuteWindow;

        // Check if today is an allowed weekday
        const isAllowedDay = Array.isArray(user.allowed_weekdays) &&
          user.allowed_weekdays.includes(userDayOfWeek);

        if (!isTimeMatch) {
          console.log('[Edge Function] Skipping user: not notification time yet');
          continue;
        }

        if (!isAllowedDay) {
          console.log(`[Edge Function] Skipping user: ${userDayOfWeek} is not an allowed day`);
          continue;
        }

        console.log('[Edge Function] Processing user notifications');

        // Get user's documents with expiry dates
        const { data: documents, error: docsError } = await supabase
          .from('documents')
          .select('id, document_name, document_type, expiry_date')
          .eq('user_id', user.id)
          .not('expiry_date', 'is', null);

        if (docsError) {
          console.error('[Edge Function] Error fetching user documents:', docsError);
          continue;
        }

        const userDayStart = Date.UTC(
          userTime.getUTCFullYear(),
          userTime.getUTCMonth(),
          userTime.getUTCDate()
        );
        const recentNotificationStartIso = new Date(
          now.getTime() - 26 * 60 * 60 * 1000
        ).toISOString();
        const userDateKey = getDateKey(userTime);

        // Check each document
        for (const doc of documents || []) {
          const expiryDate = new Date(`${doc.expiry_date}T00:00:00.000Z`);
          const expiryDayStart = Date.UTC(
            expiryDate.getUTCFullYear(),
            expiryDate.getUTCMonth(),
            expiryDate.getUTCDate()
          );
          const daysUntilExpiry = Math.round(
            (expiryDayStart - userDayStart) / (1000 * 60 * 60 * 24)
          );

          // Check if this document is at a reminder threshold
          if (
            daysUntilExpiry >= 0 &&
            Array.isArray(user.reminder_days) &&
            user.reminder_days.includes(daysUntilExpiry)
          ) {
            // Check if notification already sent today
            const { data: existingLog, error: logError } = await supabase
              .from('notification_logs')
              .select('sent_at')
              .eq('user_id', user.id)
              .eq('document_id', doc.id)
              .eq('notification_type', `expiring_${daysUntilExpiry}`)
              .gte('sent_at', recentNotificationStartIso);

            if (logError) {
              console.error('[Edge Function] Expiry notification log check failed:', logError);
              continue;
            }

            if (existingLog?.some(log => getDateKeyInTimezone(new Date(log.sent_at), user.timezone) === userDateKey)) {
              console.log('[Edge Function] Expiry notification already sent today');
              continue;
            }

            // Send FCM notification
            const notificationSent = await sendFCMNotification(
              user.fcm_token,
              {
                title: `📄 Document Expiring in ${daysUntilExpiry} ${daysUntilExpiry === 1 ? 'Day' : 'Days'}`,
                body: `Your ${doc.document_type} "${doc.document_name}" expires on ${formatDate(expiryDate)}`,
                data: {
                  documentId: doc.id,
                  documentName: doc.document_name,
                  expiryDate: doc.expiry_date,
                  daysUntilExpiry: daysUntilExpiry.toString(),
                  type: 'expiry_reminder',
                },
              },
              fcmCredentials
            );

            if (notificationSent) {
              // Log the notification
              const { error: insertError } = await supabase.from('notification_logs').insert({
                user_id: user.id,
                document_id: doc.id,
                notification_type: `expiring_${daysUntilExpiry}`,
                days_until_expiry: daysUntilExpiry,
                sent_at: new Date().toISOString(),
              });

              totalNotificationsSent++;
              if (insertError) {
                console.error('[Edge Function] Expiry notification log insert failed:', insertError);
              }
              console.log('[Edge Function] Expiry reminder sent');
            }
          }

          if (daysUntilExpiry < 0) {
            const { data: existingLog, error: logError } = await supabase
              .from('notification_logs')
              .select('sent_at')
              .eq('user_id', user.id)
              .eq('document_id', doc.id)
              .eq('notification_type', 'expired')
              .gte('sent_at', recentNotificationStartIso);

            if (logError) {
              console.error('[Edge Function] Expired-notification log check failed:', logError);
              continue;
            }

            if (existingLog?.some(log => getDateKeyInTimezone(new Date(log.sent_at), user.timezone) === userDateKey)) {
              continue;
            }

            const daysExpired = Math.abs(daysUntilExpiry);
            const notificationSent = await sendFCMNotification(
              user.fcm_token,
              {
                title: '❌ Document Expired',
                body: `${doc.document_type} "${doc.document_name}" expired ${daysExpired} ${daysExpired === 1 ? 'day' : 'days'} ago`,
                data: {
                  documentId: doc.id,
                  documentName: doc.document_name,
                  expiryDate: doc.expiry_date,
                  daysUntilExpiry: daysUntilExpiry.toString(),
                  type: 'document_expired',
                },
              },
              fcmCredentials
            );

            if (notificationSent) {
              const { error: insertError } = await supabase.from('notification_logs').insert({
                user_id: user.id,
                document_id: doc.id,
                notification_type: 'expired',
                days_until_expiry: daysUntilExpiry,
                sent_at: new Date().toISOString(),
              });

              totalNotificationsSent++;
              if (insertError) {
                console.error('[Edge Function] Expired-notification log insert failed:', insertError);
              }
              console.log('[Edge Function] Expiration notice sent');
            }
          }
        }
      } catch (userError) {
        console.error('[Edge Function] Error processing user notifications:', userError);
      }
    }

    console.log(`[Edge Function] Completed. Total notifications sent: ${totalNotificationsSent}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Checked ${users?.length || 0} users, sent ${totalNotificationsSent} notifications`,
        totalUsers: users?.length || 0,
        notificationsSent: totalNotificationsSent,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('[Edge Function] Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

// Helper: Convert UTC time to user's timezone
function convertToTimezone(date: Date, timezone: string): Date {
  try {
    // Use Intl.DateTimeFormat to get time in user's timezone
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    });

    const parts = formatter.formatToParts(date);
    const values: { [key: string]: string } = {};
    parts.forEach(({ type, value }) => {
      values[type] = value;
    });

    return new Date(
      `${values.year}-${values.month}-${values.day}T${values.hour}:${values.minute}:${values.second}Z`
    );
  } catch (e) {
    console.error('[Edge Function] Timezone conversion error:', e);
    return date; // Fallback to UTC
  }
}

// Helper: Get day of week
function getDayOfWeek(date: Date): string {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  return days[date.getUTCDay()];
}

function getDateKey(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`;
}

function getDateKeyInTimezone(date: Date, timezone: string): string {
  return getDateKey(convertToTimezone(date, timezone));
}

// Helper: Format date
function formatDate(date: Date): string {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${months[date.getUTCMonth()]} ${date.getUTCDate()}, ${date.getUTCFullYear()}`;
}

// Helper: Send FCM notification
async function sendFCMNotification(
  fcmToken: string,
  notification: { title: string; body: string; data: Record<string, string> },
  credentials: FCMCredentials
): Promise<boolean> {
  try {
    // Get OAuth2 access token
    const accessToken = await getAccessToken(credentials);

    // Send FCM v1 API request
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`;

    const response = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              color: '#0d6efd',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('[FCM] Send error:', errorText);
      return false;
    }

    const result = await response.json();
    console.log('[FCM] Notification sent successfully:', result);
    return true;
  } catch (error) {
    console.error('[FCM] Send notification error:', error);
    return false;
  }
}

// Helper: Get OAuth2 access token for FCM
async function getAccessToken(credentials: FCMCredentials): Promise<string> {
  // Create JWT header and claim set
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  // Base64URL encode header and claim set (FIX: Apply to ALL segments, not just signature)
  const base64UrlEncode = (str: string): string => {
    return btoa(str)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  };

  const jwtHeader = base64UrlEncode(JSON.stringify(header));
  const jwtClaimSet = base64UrlEncode(JSON.stringify(claimSet));

  // Sign with private key
  const signatureInput = `${jwtHeader}.${jwtClaimSet}`;

  // Import private key
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(credentials.private_key),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );

  // Sign
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signatureInput)
  );

  // Base64URL encode signature
  const jwtSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));

  const jwt = `${jwtHeader}.${jwtClaimSet}.${jwtSignature}`;

  // Exchange JWT for access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!response.ok) {
    throw new Error(`Failed to get FCM access token: ${await response.text()}`);
  }

  const data = await response.json();
  return data.access_token;
}

// Helper: Convert PEM to ArrayBuffer
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
