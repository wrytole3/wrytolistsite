# Wrytole Education — integrated document-access update

This ZIP is based on the repository ZIP supplied in this conversation. It preserves the existing site files and adds targeted changes rather than replacing the site with a new design.

## What changed
- `app.js`: opens documents through the existing Supabase `document-access` Edge Function; paid PDFs show a two-page preview until an administrator approves the individual purchase; a signed-in user can submit a payment transaction reference; downloads use the Edge Function; adds shareable document links; displays educator attribution using the public educator view; teacher name prefix is `TR.`.
- `teacher.html` and `app.js`: adds teacher profile picture upload to the existing private `education-files` bucket.
- `admin.html` and `document-purchases-admin.js`: adds an admin-only table to review individual document purchases.
- `shared-resources.js` and `school-dashboard.js`: route document opens through the same public secure reader rather than bypassing its access flow.
- `supabase/document-access-migration.sql`: additive SQL for avatar metadata, limited public educator display fields, purchase RLS, and avatar reading.
- `supabase/functions/document-access/index.ts`: source matching the current deployed `document-access` function.
- `sitemap.xml`: public-page sitemap.

## IMPORTANT — installation order
1. Keep a backup of your current repository ZIP and do not delete existing files.
2. In Supabase SQL Editor, review and run `supabase/document-access-migration.sql`. This adds a column and policies; it does not delete resource, user, subscription, or purchase rows.
3. Confirm the Supabase Edge Function `document-access` is active. Your current project already had this function active when checked, so you normally do not need to redeploy it unless you change its source. Never put the service-role key in frontend files.
4. Upload the updated files to the repository root, keeping all other files. Include the new `document-purchases-admin.js`, `sitemap.xml`, and the `supabase/` additions.
5. Wait for hosting to finish deploying. Open the site and test in a private/incognito session and then a signed-in account.

## Test checklist
- Public page still loads and lists approved resources.
- A free PDF opens without sign-in.
- Clicking Download while signed out sends the visitor to Account; after sign-in, download works.
- An unpaid paid PDF shows only the first two PDF pages.
- A signed-in user can submit a payment reference; it remains pending.
- Admin confirms payment only after checking the real transaction; approval unlocks full PDF access for that buyer.
- Teacher can upload a profile picture and its name appears as `TR. Full Name` beside their papers.
- Share link opens the selected document on the public reader.
- Existing sign-in, plans, teacher dashboard, school dashboard and uploaded files still work.

## Limitations to understand
- The two-page preview works for PDF files. Other paid formats are not converted into a two-page PDF preview by this function.
- Free documents are viewable publicly. Browser-based viewing cannot guarantee that a visitor will never save or capture the content; the secure function controls normal download links, but no website can fully prevent screenshots or copies of content displayed on a device.
- Payment references are manually verified. Submitting a reference never activates access automatically.
- Teacher avatar upload requires the migration and current Storage policies to allow uploading to the signed-in user's own folder.
- This package has not been deployed to the live site. After installation, test the checklist before announcing the feature as live.
