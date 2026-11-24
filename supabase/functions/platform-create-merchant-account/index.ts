import { createClient } from "npm:@supabase/supabase-js@2.49.8";

const PROJECT_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ADMIN_REDIRECT = "https://wathaq-platform-admin.vercel.app/merchant.html";
const MAX_BODY_BYTES = 16_384;

const corsHeaders = (origin: string) => ({
  "Access-Control-Allow-Origin": origin,
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
  "Vary": "Origin",
});

function allowedOrigin(origin: string | null): origin is string {
  if (!origin) return false;
  if (origin === "https://wathaq-platform-admin.vercel.app") return true;
  try {
    const url = new URL(origin);
    return url.protocol === "https:" &&
      /^wathaq-platform-admin-[a-z0-9-]+-novexa14\.vercel\.app$/.test(url.hostname);
  } catch {
    return false;
  }
}

function json(status: number, body: Record<string, unknown>, origin: string) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

function requiredString(value: unknown, label: string, min: number, max: number): string {
  if (typeof value !== "string") throw new Error(`${label} is required`);
  const trimmed = value.trim();
  if (trimmed.length < min || trimmed.length > max) throw new Error(`${label} must be ${min}-${max} characters`);
  return trimmed;
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  if (!allowedOrigin(origin)) {
    return new Response("Origin not allowed", { status: 403, headers: { "Vary": "Origin" } });
  }
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 204, headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" }, origin);
  }
  if (!PROJECT_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    return json(500, { error: "server_configuration_missing" }, origin);
  }

  try {
    const contentLength = Number(req.headers.get("content-length") ?? "0");
    if (contentLength > MAX_BODY_BYTES) return json(413, { error: "request_too_large" }, origin);

    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!token) return json(401, { error: "authentication_required" }, origin);

    const userClient = createClient(PROJECT_URL, ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { Authorization: authHeader } },
    });
    const service = createClient(PROJECT_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });

    const { data: authData, error: authError } = await userClient.auth.getUser(token);
    if (authError || !authData.user) return json(401, { error: "invalid_session" }, origin);
    const actorId = authData.user.id;

    const { data: adminRow, error: adminError } = await service
      .from("platform_admins")
      .select("user_id")
      .eq("user_id", actorId)
      .maybeSingle();
    if (adminError) throw new Error("Could not verify platform administrator");
    if (!adminRow) return json(403, { error: "super_admin_required" }, origin);

    const body = await req.json();
    const ownerEmail = requiredString(body.owner_email, "Owner email", 5, 254).toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(ownerEmail)) throw new Error("Owner email is invalid");
    const ownerName = requiredString(body.owner_name, "Owner name", 2, 120);
    const name = requiredString(body.name, "Merchant name", 2, 120);
    const slug = requiredString(body.slug, "Merchant slug", 2, 80).toLowerCase();
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) throw new Error("Merchant slug is invalid");

    const planKey = requiredString(body.plan_key, "Plan", 1, 40);
    const durationMonths = Number(body.duration_months ?? 1);
    if (!Number.isInteger(durationMonths) || durationMonths < 1 || durationMonths > 12) {
      throw new Error("Subscription duration must be 1 to 12 months");
    }
    const billingStatus = String(body.billing_status ?? "admin_assigned");
    if (!["admin_assigned", "manual_paid", "complimentary"].includes(billingStatus)) {
      throw new Error("Billing status is invalid");
    }

    const { data: plan, error: planError } = await service
      .from("subscription_plans")
      .select("plan_key")
      .eq("plan_key", planKey)
      .eq("is_active", true)
      .maybeSingle();
    if (planError) throw new Error("Could not verify the selected plan");
    if (!plan) throw new Error("Selected subscription plan is unavailable");

    const { data: duplicate, error: duplicateError } = await service
      .from("merchants")
      .select("id")
      .eq("slug", slug)
      .maybeSingle();
    if (duplicateError) throw new Error("Could not verify merchant slug");
    if (duplicate) return json(409, { error: "merchant_slug_already_exists" }, origin);

    let owner: any = null;
    for (let page = 1; page <= 100; page++) {
      const { data: usersPage, error: listError } = await service.auth.admin.listUsers({ page, perPage: 1000 });
      if (listError) throw new Error("Could not search existing WATHAQ accounts");
      const found = usersPage.users.find((u) => (u.email ?? "").toLowerCase() === ownerEmail);
      if (found) {
        owner = found;
        break;
      }
      if (usersPage.users.length < 1000) break;
    }

    let invitationSent = false;
    if (owner) {
      const confirmed = Boolean(owner.email_confirmed_at || owner.confirmed_at);
      const pendingWathaqInvite = owner.user_metadata?.wathaq_pending_merchant_invite === true;
      if (!confirmed && !pendingWathaqInvite) {
        return json(409, { error: "owner_email_has_unverified_account", hint: "Use a verified account or resolve the existing pending invitation first." }, origin);
      }
      if (confirmed && owner.user_metadata?.wathaq_merchant_account === true) {
        return json(409, { error: "owner_already_has_merchant_account" }, origin);
      }
    } else {
      const { data: inviteData, error: inviteError } = await service.auth.admin.inviteUserByEmail(ownerEmail, {
        data: {
          full_name: ownerName,
          wathaq_pending_merchant_invite: true,
          wathaq_invited_by_platform: true,
        },
        redirectTo: ADMIN_REDIRECT,
      });
      if (inviteError || !inviteData.user) {
        const message = inviteError?.message ?? "Could not create the invitation";
        return json(400, { error: "merchant_owner_invitation_failed", message }, origin);
      }
      owner = inviteData.user;
      invitationSent = true;
    }

    const payload = {
      p_owner_user_id: owner.id,
      p_name: name,
      p_slug: slug,
      p_plan_key: planKey,
      p_duration_months: durationMonths,
      p_billing_status: billingStatus,
      p_category: typeof body.category === "string" ? body.category.trim().slice(0, 80) || null : null,
      p_description: typeof body.description === "string" ? body.description.trim().slice(0, 1000) || null : null,
      p_country_code: typeof body.country_code === "string" ? body.country_code.trim().toUpperCase() : "YE",
      p_city: typeof body.city === "string" ? body.city.trim().slice(0, 100) || null : null,
      p_address: typeof body.address === "string" ? body.address.trim().slice(0, 240) || null : null,
      p_phone: typeof body.phone === "string" ? body.phone.trim().slice(0, 40) || null : null,
      p_email: typeof body.store_email === "string" ? body.store_email.trim().toLowerCase().slice(0, 254) || null : null,
      p_timezone: typeof body.timezone === "string" ? body.timezone.trim().slice(0, 80) : "Asia/Aden",
    };

    const { data: created, error: createError } = await userClient.rpc("admin_create_merchant_account", payload);
    if (createError || !created?.ok) {
      return json(400, {
        error: "merchant_account_creation_failed",
        message: createError?.message ?? created?.error ?? "The account transaction was not completed",
        pending_invite_kept: invitationSent,
      }, origin);
    }

    const userMetadata = {
      ...(owner.user_metadata ?? {}),
      full_name: ownerName,
      wathaq_pending_merchant_invite: false,
      wathaq_merchant_account: true,
      wathaq_merchant_id: created.merchant_id,
      wathaq_merchant_name: name,
      wathaq_subscription_plan: planKey,
    };
    const { error: metadataError } = await service.auth.admin.updateUserById(owner.id, {
      user_metadata: userMetadata,
    });

    return json(200, {
      ok: true,
      invitation_sent: invitationSent,
      owner_email: ownerEmail,
      merchant_id: created.merchant_id,
      subscription_id: created.subscription_id,
      plan_key: created.plan_key,
      status: created.subscription_status,
      starts_at: created.starts_at,
      ends_at: created.ends_at,
      metadata_warning: metadataError ? "Account created, but welcome metadata could not be updated. Admin should retry profile metadata update." : null,
    }, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error";
    const clientError = /required|must be|invalid|unavailable|characters|slug/i.test(message);
    return json(clientError ? 400 : 500, { error: clientError ? "invalid_request" : "internal_error", message }, origin);
  }
});
