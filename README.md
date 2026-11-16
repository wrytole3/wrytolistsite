# Wrytolistsite Education Website

## Separate pages
- `index.html`: public home and approved paper library
- `pricing.html`: standalone learner/teacher pricing and Chipper Cash payment-reference form
- `account.html`: sign-in, account creation and teacher-access request
- `teacher.html`: teacher dashboard, activation status, uploads and download-credit history
- `school.html`: school dashboard with one-time activation, school packages and download history
- `app-config.js`: public Supabase URL/key, Chipper Cash URL and existing storage bucket
- `wrytole-access-credit-migration.sql`: additive database migration for activation, package credits, ledger, role requests and server-side checks
- `supabase/functions/document-access/index.ts`: secure document access and atomic download-credit deduction
- `app.js`: shared website logic
- `styles.css`: responsive styling and night/day theme
- `supabase-setup.sql`: database policies, teacher requests, plan setup and private storage bucket
- `DEPLOYMENT.md`: phone-friendly installation steps

The website uses the existing Supabase project and its public publishable key. Never put a service-role/secret key in browser code.

## Payment behaviour
Chipper link: https://chipper.me/@Kagumya438. New pricing is one-time teacher activation UGX 10,000, one-time school activation UGX 20,000, and download-credit packages. Payment references remain pending until an administrator verifies them. See `ACCESS-CREDIT-UPDATE.md` and run `wrytole-access-credit-migration.sql`.

## Paper behaviour
Approved teachers can upload documents to a private Supabase Storage bucket. The resource record is created as approved, so it appears on the public site after successful upload. Teachers cannot gain teacher privileges by selecting a role at signup; an administrator must approve their role.

## Honest limitations
The package implements frontend sign-in/sign-up, resource listing, file uploads, pricing and payment-reference submissions. The access-credit update adds a dedicated administrator payment-review panel and server-side download-credit enforcement through the `document-access` Edge Function. These require the SQL migration and Edge Function deployment described in `ACCESS-CREDIT-UPDATE.md`. Run the SQL file and test in your own Supabase project before relying on it in production.
