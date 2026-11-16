# Wrytole access-credit update

This update is based on the supplied `wrytolistsite-main.zip`. It keeps the existing pages, Supabase project configuration, resources, private `education-files` bucket, Chipper Cash link, and manual administrator payment verification. It adds the new activation and download-credit model.

## New pricing implemented

- Teacher activation: one-time UGX 10,000. No monthly subscription. Activated teachers can upload. Downloading their own uploaded resources is free.
- School activation: one-time UGX 20,000. No monthly subscription.
- Student/individual/teacher download packages: 10 / 1,000; 20 / 2,000; 30 / 3,000; 40 / 4,000; 50 / 5,000 UGX.
- School download packages: 10 / 3,000; 20 / 5,000; 30 / 7,000; 40 / 9,000; 50 / 11,000 UGX.
- Admin verification creates activation or credits. Credits are deducted by the secure `document-access` Edge Function, not by browser JavaScript.
- Student / teacher / school dashboards show the applicable activation and credit balance.
- School signup requests are recorded as pending applications. The profile remains `student` until an administrator approves it; the account page then routes approved school users to `school.html`.
- Existing subscription/payment tables and historical rows are retained; active legacy plans are disabled.

## Required installation sequence

1. Back up the current GitHub repository and confirm this ZIP is the current source version.
2. In the existing Supabase project, open SQL Editor and run `wrytole-access-credit-migration.sql`. It is additive and does not delete users, resources, uploads, or historical payments/subscriptions.
3. Deploy `supabase/functions/document-access/index.ts` to the existing Edge Function named `document-access`. Keep the existing Supabase environment secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) configured on the function. Never place a service-role key in browser code.
4. Upload the updated site files to the existing GitHub repository root, preserving the repository's existing deployment workflow. Do not create a second Supabase project or a new storage bucket.
5. Confirm the deployment is complete, then test with separate student, approved teacher, approved school, and admin accounts.

## Verification checklist

- New student signup creates a `student` profile.
- Teacher/school signup creates a pending application; it does not grant elevated role until admin approval.
- After approving a school application, sign-in routes the user to School Dashboard (not Student Dashboard).
- Teacher activation payment of UGX 10,000 and school activation payment of UGX 20,000 remain pending until admin verifies the Chipper transaction.
- Admin approval activates teacher/school access once. A second activation cannot be approved.
- Student/individual/teacher package purchases add the exact credits at the stated prices; school package purchases add credits at school prices.
- Downloads consume one credit atomically. A failed file retrieval does not consume a credit. A teacher downloading their own resource is exempt.
- Exhausted balance blocks download with a clear message.
- Teacher/school upload is blocked until activation; the database Storage/resource policies also enforce activation.
- Existing approved resources and files still appear and open.
- Payment references and review history remain visible in the new access-payment admin panel.

## Important deployment boundary

The ZIP and migration are prepared, but they have **not** been deployed to GitHub, Cloudflare, or Supabase from this chat. The migration and Edge Function must be installed in your existing project before the new payment and download rules can work. The existing live website will continue running its current code until the updated files are deployed.
