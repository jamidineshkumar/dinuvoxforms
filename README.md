# DinuVoX Forms — Independent React + Supabase build

This version runs independently of Base44. It uses React, Vite, React Router, and Supabase Auth/Postgres. It does not import the Base44 SDK or Base44 Vite plugin and it does not display fake/demo form data.

## Included features

- Responsive DinuVoX Forms landing page and branded sign-in/sign-up
- Supabase authentication
- Form dashboard with search, status filters, publishing, unpublishing and deletion
- Starter templates for dance auditions, event registration, feedback, student surveys, contact forms and quizzes
- Form builder with common field types, required validation, colors, layout settings and preview
- Public form links and submission persistence
- Response table with search and CSV export
- Analytics summary and recent submission chart
- Account display-name settings and Light/Dark/System appearance
- Form assignments with branded invitation emails (requires Supabase Edge Function + Resend configuration)
- Supabase SQL schema and row-level security policies

The supplied Base44 code includes a much larger studio/editor feature set. This independent first pass prioritizes the core end-to-end workflow and a clean deployment foundation; features that relied on Base44-specific services have to be reimplemented against Supabase rather than copied unchanged.

## 1. Configure Supabase

1. Create or open a project at https://supabase.com/dashboard.
2. Open **SQL Editor**, create a new query, paste the contents of `supabase/schema.sql`, and run it.
3. Open **Project Settings → API** and copy the Project URL and the publishable/anon key.
4. Copy `.env.example` to `.env.local` in the project root and set:

   ```env
   VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   VITE_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
   ```

   Use only the browser-safe publishable/anon key here. **Never put a Supabase `service_role` or secret key in a `VITE_` variable.**
5. In Supabase **Authentication → URL Configuration**, set the Site URL to your local URL while developing (`http://localhost:5173`) and add your deployed Vercel URL to Redirect URLs.

If the environment values are missing, the app shows a setup screen rather than inventing demo data. The setup screen can save a browser-local Supabase URL and publishable/anon key for previewing on that device; for a production deployment, use Vercel Environment Variables so all visitors receive the correct configuration.

## 2. Run locally

Install Node.js 20.19+ or 22.12+ and then run from this folder:

```bash
npm install
npm run dev
```

Open the local URL printed by Vite, normally `http://localhost:5173`.

## 3. Deploy to Vercel (free tier)

1. Upload this folder to a new GitHub repository, or import the repository into Vercel.
2. In Vercel, choose **Add New → Project** and import the repository.
3. Framework preset: **Vite**. Build command: `npm run build`. Output directory: `dist`.
4. In Vercel **Settings → Environment Variables**, add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` for Production (and Preview/Development if needed).
5. Deploy. `vercel.json` rewrites client-side routes to `index.html` so public links such as `/f/my-form-1234` work on refresh.
6. Add the new `https://your-project.vercel.app` domain to Supabase Auth's allowed redirect URLs.

## Form invitation emails

1. Run `supabase/migrations/20261025000000_form_assignments.sql` in Supabase SQL Editor (or apply it with the Supabase CLI).
2. Deploy the `supabase/functions/send-form-invitation` Edge Function.
3. Configure these Edge Function secrets: `RESEND_API_KEY`, `EMAIL_FROM` (a verified Resend sender), and `PUBLIC_APP_URL` (for example `https://dinuvoxforms.vercel.app`). Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions; never expose the service-role key in frontend variables.
4. Publish a form, open its editor, and use **Assign this form** to send the invitation.

## DinuVoX-branded authentication and transactional emails

DinuVoX can use its own sender address and branded email designs instead of Supabase's default email delivery. **This keeps Supabase Auth as the identity/session system** (so existing user ownership and row-level security remain intact) while the messages are delivered through your Resend account. Do not replace this with a frontend-only OTP check; verification must remain server-side.

### Configure custom delivery (one-time)

1. In Resend, add and verify a domain you control (for example, `mail.yourdomain.com`) and publish the DNS records Resend provides. You need a verified sender to deliver production email reliably.
2. In Supabase Dashboard, open **Project Settings → Authentication → SMTP Settings** (the exact menu label may vary) and enable custom SMTP.
3. Use these Resend SMTP settings:
   - Host: `smtp.resend.com`
   - Port: `465` (SSL) or `587` (STARTTLS, if offered)
   - Username: `resend`
   - Password: your Resend API key (keep it private)
   - Sender email: an address on your verified domain, such as `no-reply@mail.yourdomain.com`
   - Sender name: `DinuVoX Forms`
4. In **Authentication → Email Templates**, select the OTP / Magic Link template used by your chosen sign-in flow. Copy `supabase/email-templates/otp.html` into the HTML template editor. Keep the `{{ .Token }}` variable unchanged so Supabase can insert the actual one-time code.
5. Configure the OTP length and expiry in Supabase Auth settings. Keep expiry short and enable sensible rate limits. Test with an address you control before launch.
6. Use a consistent sender and templates for invitations and other product emails. The existing invitation Edge Function sends via Resend API and needs `RESEND_API_KEY`, `EMAIL_FROM`, and `PUBLIC_APP_URL` secrets.

### Important email-client limitation

The OTP template includes a subtle CSS entrance effect for clients that support it, but many email clients strip or disable animation. The layout therefore stays polished and readable without motion. Never put secrets or OTP validation logic in the email HTML or browser code.

### Current sign-in flow

The current frontend uses email + password with Supabase Auth. The branded template above applies to Supabase Auth emails that use that template; it does **not** switch the app to passwordless OTP sign-in by itself. To make the login screen use email OTP instead of passwords, that frontend flow must be changed and tested separately.

## Database notes

- Form records belong to the authenticated owner.
- Public visitors can read only published forms and can insert submissions only when the submitted form is published.
- Owners can read/delete their own responses and manage their forms.
- Supabase Storage is not required for this core build. If you later enable image/file question uploads, create a dedicated bucket and add narrowly scoped storage policies before allowing public uploads.

## Important security notes

The frontend key is designed to be public; security depends on the SQL policies. Review the policies before using this for sensitive data. Do not collect passwords, payment-card details, medical information, or other highly sensitive data with a general-purpose public form without additional safeguards. Email confirmation settings are controlled in Supabase Auth.
