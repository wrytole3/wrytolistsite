# Install from an Android phone
1. Download and extract `wrytolistsite-complete.zip`.
2. Open https://github.com/wrytole3/wrytolistsite, branch `main`.
3. Choose **Add file → Upload files** and upload every extracted file into the repository root. Replace `index.html`, `app.js`, `styles.css` and `README.md` if prompted.
4. In Supabase Dashboard, open SQL Editor, create a new query, paste the full contents of `supabase-setup.sql`, review it and run it.
5. In Supabase Authentication → URL Configuration, add your final live website URL to allowed redirect URLs and set the Site URL.
6. Check your profile row in `profiles` and ensure your own role is `admin`. Do not make all users administrators.
7. Verify teacher applicants, then change only approved profiles to role `teacher`.
8. Wait for hosting deployment, then test account creation, sign-in, pricing, payment-reference submission and a teacher upload.

If uploading fails, confirm the SQL ran successfully, the `education-files` bucket exists and is private, the signed-in profile role is `teacher` or `admin`, and email confirmation settings are understood. Google sign-in requires configured Google OAuth credentials and redirect URLs.

Never add a Supabase service-role/secret key to the website files.
