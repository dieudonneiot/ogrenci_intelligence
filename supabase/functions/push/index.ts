// Supabase Edge Function: push
// Sends an FCM push for a focus check.
//
// Required secrets:
// - SUPABASE_SERVICE_ROLE_KEY (or SERVICE_ROLE_KEY)
// - FIREBASE_SERVICE_ACCOUNT_JSON  (the full JSON string of a Firebase service account)
//
// Note: In hosted Supabase Edge Functions, SUPABASE_URL and SUPABASE_ANON_KEY are
// typically provided automatically by the platform. If you're running locally,
// you can provide SUPABASE_URL/SUPABASE_ANON_KEY.
//
// Call:
//   POST /functions/v1/push { "focus_check_id": "<uuid>" }
//
// The caller must be authenticated and must have access to that focus_check row via RLS
// (company member of the focus_check.company_id or admin).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

type Json = Record<string, unknown>;

function env(key: string): string {
  const v = Deno.env.get(key);
  if (!v || v.trim().length === 0) throw new Error(`Missing env: ${key}`);
  return v.trim();
}

function envAny(keys: string[]): string {
  for (const key of keys) {
    const v = Deno.env.get(key);
    if (v && v.trim().length > 0) return v.trim();
  }
  throw new Error(`Missing env (any of): ${keys.join(", ")}`);
}

function looksLikeJwt(v: string) {
  return v.startsWith("eyJ");
}

function envJwtAny(keys: string[]): string {
  for (const key of keys) {
    const v = Deno.env.get(key);
    if (v && v.trim().length > 0 && looksLikeJwt(v.trim())) return v.trim();
  }
  return envAny(keys);
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function getBearer(req: Request): string | null {
  const h = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!h) return null;
  const m = h.match(/^Bearer\s+(.+)$/i);
  return m?.[1] ?? null;
}

async function fcmAccessToken(serviceAccountJson: string): Promise<{ token: string; projectId: string }> {
  const credentials = JSON.parse(serviceAccountJson);
  const projectId = credentials.project_id as string | undefined;
  if (!projectId) throw new Error("Missing project_id in service account JSON");

  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  const token = tokenResponse?.token;
  if (!token) throw new Error("Failed to get Google access token");
  return { token, projectId };
}

async function sendFcm({
  accessToken,
  projectId,
  token,
  title,
  body,
  data,
}: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<Response> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  return await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              sound: "default",
              contentAvailable: true,
            },
          },
        },
      },
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const bearer = getBearer(req);
  if (!bearer) return jsonResponse({ error: "Missing Authorization bearer token" }, 401);

  let payload: Json;
  try {
    payload = (await req.json()) as Json;
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const focusCheckId = (payload["focus_check_id"] ?? "").toString().trim();
  if (!focusCheckId) return jsonResponse({ error: "focus_check_id required" }, 400);

  const supabaseUrl = envAny(["SUPABASE_URL"]);
  const anonKey = envJwtAny(["SUPABASE_ANON_KEY"]);
  const serviceKey = envJwtAny(["SUPABASE_SERVICE_ROLE_KEY", "SERVICE_ROLE_KEY"]);

  // 1) Use caller auth (RLS enforced) to validate access to that focus_check
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });

  const { data: focusRow, error: focusErr } = await userClient
    .from("focus_checks")
    .select("id,user_id,question,expires_at")
    .eq("id", focusCheckId)
    .maybeSingle();

  if (focusErr) return jsonResponse({ error: focusErr.message }, 400);
  if (!focusRow) return jsonResponse({ error: "Not found (or access denied)" }, 404);

  // 2) Use service role to read push tokens
  const adminClient = createClient(supabaseUrl, serviceKey);

  const { data: tokenRows, error: tokenErr } = await adminClient
    .from("push_tokens")
    .select("token")
    .eq("user_id", focusRow.user_id)
    .eq("is_active", true)
    .order("last_seen_at", { ascending: false })
    .limit(10);

  if (tokenErr) return jsonResponse({ error: tokenErr.message }, 500);
  const tokens = (tokenRows ?? []).map((r) => (r as { token: string }).token).filter(Boolean);
  if (tokens.length === 0) {
    return jsonResponse({ ok: true, sent: 0, reason: "No active push tokens for user" }, 200);
  }

  const serviceAccountJson = env("FIREBASE_SERVICE_ACCOUNT_JSON");
  const { token: accessToken, projectId } = await fcmAccessToken(serviceAccountJson);

  const title = "Instant Focus Check";
  const body = "Tap to answer within 30 seconds.";

  const data = {
    type: "focus_check",
    focus_check_id: focusCheckId,
    route: `/focus-check?id=${focusCheckId}`,
  };

  const results: Array<{ token: string; ok: boolean; status?: number; error?: string }> = [];
  for (const t of tokens) {
    try {
      const res = await sendFcm({ accessToken, projectId, token: t, title, body, data });
      if (!res.ok) {
        results.push({ token: t, ok: false, status: res.status, error: await res.text() });
      } else {
        results.push({ token: t, ok: true, status: res.status });
      }
    } catch (e) {
      results.push({ token: t, ok: false, error: (e as Error).message });
    }
  }

  const sent = results.filter((r) => r.ok).length;
  const failed = results.length - sent;

  return jsonResponse({ ok: failed === 0, sent, failed, results }, 200);
});
