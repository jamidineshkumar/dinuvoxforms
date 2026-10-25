import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("PUBLIC_APP_URL") ?? "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("EMAIL_FROM");
  const appUrl = Deno.env.get("PUBLIC_APP_URL");

  if (!supabaseUrl || !anonKey || !serviceKey || !resendKey || !from || !appUrl) {
    return response({ error: "Invitation email is not configured. Set RESEND_API_KEY, EMAIL_FROM, and PUBLIC_APP_URL." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return response({ error: "Sign in to send invitations." }, 401);

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: { user }, error: authError } = await authClient.auth.getUser();
  if (authError || !user) return response({ error: "Your session is invalid. Please sign in again." }, 401);

  let formId = "";
  let email = "";
  try {
    const body = await req.json();
    formId = String(body.formId ?? "");
    email = String(body.email ?? "").trim().toLowerCase();
  } catch {
    return response({ error: "Invalid request body." }, 400);
  }
  if (!formId || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return response({ error: "Enter a valid email address and form." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: form, error: formError } = await admin
    .from("forms").select("id,owner_id,title,slug,status")
    .eq("id", formId).eq("owner_id", user.id).single();
  if (formError || !form) return response({ error: "Form not found or you do not own it." }, 404);
  if (form.status !== "published") return response({ error: "Publish this form before sending invitations." }, 400);

  const { data: assignment, error: insertError } = await admin
    .from("form_assignments")
    .insert({ form_id: form.id, form_owner_id: user.id, recipient_email: email })
    .select("id,invite_token").single();
  if (insertError || !assignment) return response({ error: "Could not create the assignment. Apply the form assignment SQL migration first." }, 500);

  const link = `${appUrl.replace(/\/$/, "")}/f/${form.slug}?invite=${assignment.invite_token}`;
  const safeTitle = form.title.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] ?? c));
  const html = `<!doctype html><html><body style="margin:0;background:#f6f3fb;font-family:Arial,sans-serif;color:#211d1d;padding:28px 12px"><div style="max-width:600px;margin:auto;background:#fff;border:1px solid #ece5f5;border-radius:22px;overflow:hidden"><div style="padding:26px 30px;background:linear-gradient(135deg,#25143d,#7c3aed);color:white"><div style="font-size:12px;letter-spacing:3px;font-weight:bold;opacity:.9">DINUVOX FORMS</div><h1 style="font-size:26px;line-height:1.2;margin:22px 0 4px">You've been invited ✨</h1><p style="margin:0;color:#e9ddff">A form created for you</p></div><div style="padding:30px"><p style="font-size:16px;line-height:1.6">Hello,</p><p style="font-size:16px;line-height:1.6">You've been invited to complete <strong>${safeTitle}</strong>. Use the button below to open the form and submit your response.</p><p style="margin:28px 0"><a href="${link}" style="display:inline-block;background:#7c3aed;color:white;text-decoration:none;padding:14px 22px;border-radius:12px;font-weight:bold">Open your form →</a></p><p style="font-size:13px;line-height:1.6;color:#827a7a">If the button doesn't work, copy this link into your browser:<br><a style="color:#6d28d9;word-break:break-all" href="${link}">${link}</a></p><hr style="border:0;border-top:1px solid #eee7f4;margin:26px 0"><p style="font-size:12px;color:#827a7a;margin:0">Sent by DinuVoX Forms · Make forms people enjoy filling out.</p></div></div></body></html>`;

  const emailResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to: [email], subject: `You're invited: ${form.title}`, html }),
  });
  if (!emailResponse.ok) {
    await admin.from("form_assignments").delete().eq("id", assignment.id);
    return response({ error: "Email provider rejected the message. Verify your Resend sender and domain settings." }, 502);
  }
  return response({ ok: true });
});
