# DinuVoX Forms

DinuVoX Forms is a React + Vite app with Supabase/Postgres for published forms and cross-device responses.

## Authentication model

- The sign-in form uses a browser-local display name, email/username, and password.
- No email verification, OTP, Google OAuth, or invitation emails are used.
- Passwords are PBKDF2-derived with a per-profile salt; the raw password is not stored.
- Supabase Anonymous Sign-Ins are used to establish a per-profile database identity so the existing row-level security policies can protect cloud form ownership.
- Local profiles and their credential hashes are stored in the browser's localStorage. They do not sync to other devices. Clearing browser data can remove local sign-in profiles.
- The Supabase session refresh token is cached locally with the profile so the app can restore that profile's cloud workspace.

**Important limitation in this branch:** the current form editor still persists drafts to Supabase. Local-only draft storage has not yet been wired into the editor, so do not treat drafts as device-only or confidential until that is completed. This branch removes email-based authentication and email invitation UI, but it is not a complete implementation of the local-drafts requirement yet.

## Features

- Responsive DinuVoX Forms landing page and password-based local profile UI
- Form dashboard with search, status filters, publishing, unpublishing and deletion
- Templates for dance auditions, event registration, feedback, student surveys, contact forms and quizzes
- Form builder with common field types, required validation, colors, layouts and preview
- Public form links and submission persistence
- Response table with search and CSV export
- Analytics summary and recent submission chart
- Display-name settings and Light/Dark/System appearance

## Configure Supabase

1. Open your Supabase project.
2. In **Authentication → Sign In / Providers** (the exact label may vary), enable **Anonymous Sign-Ins**. This is required for the local-profile-to-cloud-workspace bridge.
3. Open **SQL Editor** and run `supabase/schema.sql` from this repository. This creates the forms/submissions tables and row-level security policies.
4. In **Project Settings → API**, copy the Project URL and publishable/anon key.
5. Create `.env.local` from `.env.example`:

   ```env
   VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
   ```

   Never put a Supabase service-role or secret key in a `VITE_` variable.
6. In **Authentication → URL Configuration**, set the Site URL to your deployed Vercel URL and add local/preview URLs only if needed.

## Run locally

Use Node.js 20.19+ or 22.12+:

```bash
npm install
npm run dev
npm run build
npm run preview
```

## Deploy to Vercel

1. Import this GitHub repository into Vercel.
2. Select **Vite** as the framework preset.
3. Set build command to `npm run build` and output directory to `dist`.
4. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to Vercel Environment Variables for Production (and Preview/Development if needed).
5. Deploy. `vercel.json` rewrites client-side routes to `index.html`, allowing public form URLs to load on refresh.
6. Verify that Anonymous Sign-Ins are enabled and that `supabase/schema.sql` has been applied before testing sign-up, form publishing, public submission, and response review.

## Data and security notes

- Browser-local profiles are not cloud identities and cannot be recovered on another browser/device.
- Published forms and responses are stored in Supabase so respondents on other devices can submit responses that the owner can review.
- The public browser key is intended to be visible; security relies on row-level security. Review the SQL policies before collecting sensitive data.
- Do not collect passwords, payment-card details, medical information, or other highly sensitive data in general-purpose public forms without additional safeguards.
