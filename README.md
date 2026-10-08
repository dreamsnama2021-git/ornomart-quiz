# Ornomart Jewellery Quiz

- `index.html`: the quiz players use (details form or Google sign-in, then 10 MCQs with a 7-minute timer, then score and coupon).
- `admin.html`: admin dashboard (sign in with email/password or Google, reset password, see all entries, check coupons, mark them redeemed, export CSV).
- `config.js`: Supabase Project URL and publishable key.
- `supabase/schema.sql`: database tables and security rules.

## Setup

1. **Database:** In Supabase, open the project, go to **SQL Editor**, paste all of `supabase/schema.sql` and click **Run**.
   (Already done for `gm.greensmedia@gmail.com's Project`.)
2. **Admin login:** Go to **Authentication > Users > Add user > Create new user**. Enter the admin email and a password, and tick **Auto Confirm User**.
   Then add that email to the admin list in the SQL Editor (use lowercase):
   ```sql
   insert into public.quiz_admins (email) values ('your-admin@email.com');
   ```
   An admin who signs in with Google must use a Google account whose email is on this list.
3. **Keep sign-ups on.** Players who use "Continue with Google" need it. This is safe: only emails in `quiz_admins` can see any data.
4. **Keys:** Go to **Project Settings > API**. Copy the **Project URL** and the **publishable** key into `config.js`.
   Never use the `service_role` or secret key here.
5. **Redirect URLs** (needed for Google sign-in and password reset): go to **Authentication > URL Configuration**.
   - **Site URL:** `https://<your-site>.pages.dev`
   - **Redirect URLs:** add `http://localhost:5173/**` and `https://<your-site>.pages.dev/**`
6. **Google sign-in:**
   1. In [Google Cloud Console](https://console.cloud.google.com/), create a project, then set up **APIs & Services > OAuth consent screen** (External, app name "Ornomart", your support email).
   2. Go to **Credentials > Create credentials > OAuth client ID > Web application**.
      - **Authorized JavaScript origins:** `http://localhost:5173` and `https://<your-site>.pages.dev`
      - **Authorized redirect URI:** `https://hutcxlcobtaccnvsneyg.supabase.co/auth/v1/callback`
   3. Copy the **Client ID** and **Client secret** into Supabase **Authentication > Sign In / Providers > Google**, switch it on and save.
   The quiz only shows "Continue with Google" once this provider is on.
7. **Password reset emails:** Supabase's built-in email sender is rate-limited and only delivers to members of the Supabase organization. For other admin emails, set up custom SMTP under **Authentication > Emails > SMTP Settings**.
8. **Hosting (GitHub + Cloudflare Pages):** Push this folder to a GitHub repo. In Cloudflare, go to **Workers & Pages > Create > Pages > Connect to Git**, pick the repo, leave the build command empty and set the output directory to `/`.
   - Quiz: `https://<your-site>.pages.dev/`
   - Admin: `https://<your-site>.pages.dev/admin.html`
