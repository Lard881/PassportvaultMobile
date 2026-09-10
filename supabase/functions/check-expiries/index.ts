// =====================================================
// SUPABASE EDGE FUNCTION: check-expiries
// Runs every 15 minutes via pg_cron
// Checks document expiries and sends FCM push notifications
// Uses FCM HTTP v1 API with OAuth2
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// FCM HTTP v1 API endpoint
const FCM_API_URL = "https://fcm.googleapis.com/v1/projects/passportvault-652d6/messages:send";

serve(async (req) => {
  try {
    console.log('[check-expiries] Function invoked');

    // Initialize Supabase client with service role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get current UTC time
    const now = new Date();
    const currentUTCHour = now.getUTCHours();
    const currentUTCMinute = now.getUTCMinutes();
    
    console.log(`[check-expiries] Current UTC time: ${currentUTCHour}:${currentUTCMinute}`);

    // STEP 1: Find users whose notification window matches current time
    // We check users whose notification_time (in their timezone) falls within the last 15 minutes
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, email, fcm_token, timezone, notification_time, reminder_days, allowed_weekdays')
      .eq('notification_enabled', true)
      .not('fcm_token', 'is', null);

    if (usersError) {
      console.error('[check-expiries] Error fetching users:', usersError);
      return new Response(JSON.stringify({ error: 'Failed to fetch users' }), { status: 500 });
    }

    console.log(`[check-expiries] Found ${users?.length || 0} users with notifications enabled`);

    let totalNotificationsSent = 0;
    const results = [];

    // STEP 2: Process each user
    for (const user of users || []) {
      try {
        // Check if today is an allowed weekday for this user
        const userNow = convertToUserTimezone(now, user.timezone);
        const userWeekday = getWeekdayName(userNow).toLowerCase();
        
        if (!user.allowed_weekdays?.includes(userWeekday)) {
          console.log(`[check-expiries] Skipping user ${user.email} - today (${userWeekday}) not in allowed weekdays`);
          continue;
        }

        // Check if user's notification time matches current window (within 15 minutes)
        const userNotificationTime = parseTime(user.notification_time);
        const userCurrentTime = {
          hour: userNow.getHours(),
          minute: userNow.getMinutes()
        };

        if (!isTimeInWindow(userCurrentTime, userNotificationTime, 15)) {
          console.log(`[check-expiries] Skipping user ${user.email} - not in notification window`);
          continue;
        }

        console.log(`[check-expiries] Processing user: ${user.email}`);

        // STEP 3: Get user's documents that need notifications
        const { data: documents, error: docsError } = await supabase
          .from('documents')
          .select('id, document_name, document_type, expiry_date')
          .eq('user_id', user.id)
          .not('expiry_date', 'is', null);

        if (docsError) {
          console.error(`[check-expiries] Error fetching documents for ${user.email}:`, docsError);
          continue;
        }

        console.log(`[check-expiries] User ${user.email} has ${documents?.length || 0} documents`);

        // STEP 4: Check each document for expiry
        const notificationsToSend = [];
        
        for (const doc of documents || []) {
          const expiryDate = new Date(doc.expiry_date);
          const daysUntilExpiry = Math.ceil((expiryDate.getTime() - userNow.getTime()) / (1000 * 60 * 60 * 24));

          console.log(`[check-expiries] Document: ${doc.document_name} - Days until expiry: ${daysUntilExpiry}`);

          // Check if this matches any reminder day
          for (const reminderDay of user.reminder_days || []) {
            if (daysUntilExpiry === reminderDay) {
              // Check if we already sent this notification today
              const { data: existingLog } = await supabase
                .from('notification_logs')
                .select('id')
                .eq('user_id', user.id)
                .eq('document_id', doc.id)
                .eq('notification_type', `expiring_${reminderDay}`)
                .gte('sent_at', new Date(userNow.getFullYear(), userNow.getMonth(), userNow.getDate()).toISOString())
                .single();

              if (!existingLog) {
                notificationsToSend.push({
                  document: doc,
                  type: `expiring_${reminderDay}`,
                  daysUntilExpiry: reminderDay,
                  title: '⚠️ Document Expiring Soon',
                  body: `${doc.document_name} (${doc.document_type}) expires in ${reminderDay} ${reminderDay === 1 ? 'day' : 'days'}`
                });
              }
            }
          }

          // Check for expired documents (send on allowed weekdays)
          if (daysUntilExpiry < 0) {
            const daysExpired = Math.abs(daysUntilExpiry);
            
            // Check if we already sent expired notification today
            const { data: existingLog } = await supabase
              .from('notification_logs')
              .select('id')
              .eq('user_id', user.id)
              .eq('document_id', doc.id)
              .eq('notification_type', 'expired')
              .gte('sent_at', new Date(userNow.getFullYear(), userNow.getMonth(), userNow.getDate()).toISOString())
              .single();

            if (!existingLog) {
              notificationsToSend.push({
                document: doc,
                type: 'expired',
                daysUntilExpiry: daysUntilExpiry,
                title: '❌ Document Expired',
                body: `${doc.document_name} (${doc.document_type}) expired ${daysExpired} ${daysExpired === 1 ? 'day' : 'days'} ago`
              });
            }
          }
        }

        // STEP 5: Send FCM notifications
        console.log(`[check-expiries] Sending ${notificationsToSend.length} notifications to ${user.email}`);

        // Get Firebase service account from system_config
        const { data: configData } = await supabase
          .from('system_config')
          .select('value')
          .eq('key', 'fcm_server_key')
          .single();

        if (!configData?.value) {
          console.error('[check-expiries] FCM service account not configured');
          continue;
        }

        // Parse service account JSON
        const serviceAccount = JSON.parse(configData.value);

        for (const notification of notificationsToSend) {
          try {
            // Send FCM push notification (pass service account directly)
            await sendFCMNotification(user.fcm_token, notification.title, notification.body, serviceAccount);

            // Log the notification
            await supabase
              .from('notification_logs')
              .insert({
                user_id: user.id,
                document_id: notification.document.id,
                notification_type: notification.type,
                days_until_expiry: notification.daysUntilExpiry
              });

            totalNotificationsSent++;
            console.log(`[check-expiries] ✅ Sent: ${notification.title} - ${notification.body}`);
          } catch (error) {
            console.error(`[check-expiries] Failed to send notification:`, error);
          }
        }

        // Update last notification check
        await supabase
          .from('users')
          .update({ last_notification_check: now.toISOString() })
          .eq('id', user.id);

        results.push({
          user: user.email,
          notificationsSent: notificationsToSend.length
        });

      } catch (error) {
        console.error(`[check-expiries] Error processing user ${user.email}:`, error);
      }
    }

    console.log(`[check-expiries] ========== COMPLETE: ${totalNotificationsSent} notifications sent ==========`);

    return new Response(
      JSON.stringify({
        success: true,
        totalNotificationsSent,
        usersProcessed: results.length,
        results
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200
      }
    )

  } catch (error) {
    console.error('[check-expiries] Fatal error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500
      }
    )
  }
})

// =====================================================
// HELPER FUNCTIONS
// =====================================================

/**
 * Send FCM push notification using HTTP v1 API with OAuth2
 */
async function sendFCMNotification(fcmToken: string, title: string, body: string, serviceAccount: any) {
  // Get OAuth2 access token from service account
  const accessToken = await getAccessToken(serviceAccount);

  const message = {
    message: {
      token: fcmToken,
      notification: {
        title: title,
        body: body
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          color: "#0d6efd"
        }
      },
      apns: {
        headers: {
          "apns-priority": "10"
        },
        payload: {
          aps: {
            sound: "default"
          }
        }
      }
    }
  };

  const response = await fetch(FCM_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    },
    body: JSON.stringify(message)
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`FCM v1 request failed: ${response.status} - ${error}`);
  }

  return await response.json();
}

/**
 * Get OAuth2 access token from Firebase service account
 */
async function getAccessToken(serviceAccount: any): Promise<string> {

  const jwtHeader = {
    alg: "RS256",
    typ: "JWT"
  };

  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  };

  // Create JWT
  const encodedHeader = base64UrlEncode(JSON.stringify(jwtHeader));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(jwtClaimSet));
  const signatureInput = `${encodedHeader}.${encodedClaimSet}`;

  // Sign with private key
  const signature = await signJWT(signatureInput, serviceAccount.private_key);
  const jwt = `${signatureInput}.${signature}`;

  // Exchange JWT for access token
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  });

  if (!response.ok) {
    throw new Error(`Failed to get access token: ${await response.text()}`);
  }

  const data = await response.json();
  return data.access_token;
}

/**
 * Sign JWT with RSA-SHA256
 */
async function signJWT(data: string, privateKey: string): Promise<string> {
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256"
    },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    dataBuffer
  );

  return base64UrlEncode(new Uint8Array(signatureBuffer));
}

/**
 * Base64 URL encode
 */
function base64UrlEncode(data: string | Uint8Array): string {
  let base64: string;
  
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    const str = String.fromCharCode(...Array.from(data));
    base64 = btoa(str);
  }

  return base64
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

/**
 * Convert UTC time to user's timezone
 */
function convertToUserTimezone(date: Date, timezone: string): Date {
  try {
    return new Date(date.toLocaleString('en-US', { timeZone: timezone }));
  } catch {
    // Fallback to UTC if timezone is invalid
    return date;
  }
}

/**
 * Get weekday name from date
 */
function getWeekdayName(date: Date): string {
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  return days[date.getDay()];
}

/**
 * Parse time string (HH:MM:SS) to object
 */
function parseTime(timeString: string): { hour: number; minute: number } {
  const parts = timeString.split(':');
  return {
    hour: parseInt(parts[0]),
    minute: parseInt(parts[1])
  };
}

/**
 * Check if current time is within notification window
 */
function isTimeInWindow(
  currentTime: { hour: number; minute: number },
  targetTime: { hour: number; minute: number },
  windowMinutes: number
): boolean {
  const currentMinutes = currentTime.hour * 60 + currentTime.minute;
  const targetMinutes = targetTime.hour * 60 + targetTime.minute;
  const diff = Math.abs(currentMinutes - targetMinutes);
  
  return diff <= windowMinutes;
}
