# Wrytolistsite Education Website

## Separate pages
- `index.html`: public home and approved paper library
- `pricing.html`: standalone learner/teacher pricing and Chipper Cash payment-reference form
- `account.html`: sign-in, account creation and teacher-access request
- `teacher.html`: standalone teacher dashboard and file upload form
- `app-config.js`: public Supabase URL/key, Chipper Cash URL and storage bucket
- `app.js`: shared website logic
- `styles.css`: responsive styling and night/day theme
- `supabase-setup.sql`: database policies, teacher requests, plan setup and private storage bucket
- `DEPLOYMENT.md`: phone-friendly installation steps

The website uses the existing Supabase project and its public publishable key. Never put a service-role/secret key in browser code.

## Payment behaviour
Chipper link: https://chipper.me/@Kagumya438. The website records submitted references as pending. The profile link does not automatically confirm payment; an administrator must verify payment and create/update the subscription. Teacher plan is set to UGX 50,000 for 30 days.

## Paper behaviour
Approved teachers can upload documents to a private Supabase Storage bucket. The resource record is created as approved, so it appears on the public site after successful upload. Teachers cannot gain teacher privileges by selecting a role at signup; an administrator must approve their role.

## Honest limitations
The package implements frontend sign-in/sign-up, resource listing, file uploads, pricing and payment-reference submissions. It does not include a complete admin payment-review screen or a trusted server function for activating subscriptions. Browser-side download-limit checks are not secure enforcement. Those need an admin process and a server/Edge Function. Run the SQL file and test in your own Supabase project before relying on it in production.
