# Module 1 — Plain HTML/CSS/JS version

No Node.js, no npm, no build step required to run this. Just files a
browser can open directly, or that any static host (Vercel, GitHub Pages,
Netlify) can serve as-is.

## Files

```
index.html          Entry point — redirects to login or dashboard based on session
login.html           Login screen
dashboard.html        Example protected page (sidebar/topbar layout)
css/styles.css        All shared styles
js/config.js          Your Supabase URL + anon key (edit this!)
js/auth-guard.js      requireAuth() — session + role check, used on every protected page
schema.sql            Same as before — run once in Supabase SQL Editor (unchanged)
```

## 1. Run the database migration

Same as before — this part never depended on the frontend language.
Supabase Dashboard → SQL Editor → paste `schema.sql` → Run.

## 2. Add your Supabase keys

Open `js/config.js` and replace the two placeholder values:

```js
const SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-PUBLIC-KEY';
```

Get both from Supabase Dashboard → Settings → API. These are safe to have
directly in the file — the browser was always going to see them anyway.
Row Level Security in `schema.sql` is what actually enforces access.

## 3. Open it and test

Just double-click `login.html` to open it in your browser, or:

```bash
# any of these work, whichever you have:
python3 -m http.server 8000
# then visit http://localhost:8000/login.html
```

Sign up your first user (Supabase Dashboard → Authentication → Add user, or
build a simple signup form) — it becomes `admin` automatically per the
trigger in `schema.sql`. Log in at `login.html` and you should land on
`dashboard.html` with your name, role badge, and nav.

## 4. Adding a new protected page

Copy this pattern into any new `.html` file:

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="js/config.js"></script>
<script src="js/auth-guard.js"></script>
<script>
  requireAuth({ allowedRoles: ['admin'] }).then(({ session, profile }) => {
    // session + profile are confirmed here — render your page content
  });
</script>
```

Omit `allowedRoles` to allow any logged-in user regardless of role.

## 5. Deploying

Since there's no build step, deployment is just "upload these files":

- **Vercel**: drag the whole folder into a new project (or connect the
  GitHub repo) — Vercel auto-detects it as a static site, no config needed.
- **GitHub Pages**: push to a repo, enable Pages in repo Settings, done.

## What's different from the TypeScript/Next.js version

| | Next.js version | This version |
|---|---|---|
| Requires Node/npm to run | Yes | No |
| Type safety | Yes (TypeScript) | No |
| Component reuse | React components | Copy/paste HTML blocks or extend `renderNav`-style JS |
| Config | `.env.local` | `js/config.js` (plain values) |
| RLS / database | Same `schema.sql` | Same `schema.sql` |

Nothing about your database, RLS policies, or roles changes — only how the
frontend is built and served.
# indoseasons
# indoseasons
