Wrytole admin + school dashboard overlay

Files target the existing wrytole3/wrytolistsite repository and existing Supabase project.

1. Back up existing repository files.
2. Replace admin.js with this package's admin.js. It fixes timestamp queries to use submitted_at for teacher_applications and payment_submissions and adds an admin upload/publish form using the existing resources table and education-files bucket.
3. Add shared-resources.js to the repository root, then add this script after app.js in teacher.html: <script defer src="shared-resources.js"></script>
4. Add school.html and school-dashboard.js to the repository root. School dashboard URL will be /school.html.

The package is not deployed; GitHub write access previously returned 403. Confirm RLS policies allow admin to manage resources and approved teacher/school roles to upload to education-files. School dashboard permits profiles.role school or admin. The current schema's resources table is shared; admin/school uploads use status approved and show publicly. Paid-resource checkout is not implemented here. Test on staging or back up before replacing files.