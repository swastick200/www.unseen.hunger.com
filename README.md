# Unseen Hunger

Next.js landing page for the Unseen Hunger street food brand.

## Run

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Deploy Online

Use the Next.js app for deployment. GitHub Pages alone will not save feedback because it cannot run the API route or write to storage.

Recommended deploy path:

1. Push this repo to GitHub.
2. Create a Supabase project.
3. Run the SQL in `supabase/feedback.sql`.
4. Import the GitHub repo into Vercel.
5. Add the environment variables from `.env.example`.
6. Deploy.

Required environment variables:

```bash
ADMIN_TOKEN=unseenhg2056
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_FEEDBACK_TABLE=feedback_entries
```

Do not commit the real service role key to GitHub. Keep it only in your hosting provider environment settings.

After deployment:

- customer feedback posts to the Next.js API route
- the API stores entries in Supabase
- the owner reads entries from `/admin` using the admin token

## Static Server

If you want to use the static `public` site with the local feedback backend:

```bash
npm install
npm run server
```

Then open `http://localhost:3000`.

## Notes

- The React/Next.js version lives in `app/`.
- Local development can still use `data/feedback.json`.
- Hosted deployments should use Supabase-backed storage through the Next.js API route.
- GitHub Pages is fine for a brochure site, but not for central feedback storage.
- Public brand photos were sourced from public business listing image URLs.
- I could not verify a public official Instagram profile from indexed sources, so the UI says that instead of guessing a handle.
