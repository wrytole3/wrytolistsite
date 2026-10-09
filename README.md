# Wrytolistsite Education

Responsive static-first education site for free hosting on Cloudflare Pages and the existing Wrytole Supabase project.

## Deploy
1. Upload all files in this folder to the root of `https://github.com/wrytole3/wrytolistsite`.
2. Open https://dash.cloudflare.com/ → Workers & Pages → Create → Pages → Connect to Git.
3. Select `wrytole3/wrytolistsite`. Framework preset: **None**. Leave the build command blank and use `.` as the output directory if required.
4. Deploy and use the assigned `*.pages.dev` URL.

## Supabase
The frontend uses the project's public publishable key. Never place a service-role or secret key in browser code. In Supabase Authentication → URL Configuration, add the deployed URL to allowed redirect URLs. Enable Google under Authentication → Providers and configure a Google OAuth client.

## Status
This is an initial frontend scaffold: responsive landing page, search/filter, email sign-in/sign-up, Google OAuth initiation, theme toggle and reading approved resources. It does not yet provide secure educator uploads, admin moderation, protected document downloads, verified payment processing, subscription activation, download tracking, or a complete role-based dashboard. Those require reviewed Supabase RLS/storage policies and trusted server-side operations. Payment UI is informational only.
