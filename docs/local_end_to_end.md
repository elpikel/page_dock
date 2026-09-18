# Testing Pagedock end to end locally

This walks through the full flow — sign in, connect GitHub, link a repo, deploy
on push, and view the served site — against **real GitHub**, using an
[ngrok](https://ngrok.com) tunnel so GitHub can deliver webhooks to your machine.

Two things can't reach `localhost` on their own, which is why we need setup:

- **OAuth** — GitHub redirects the browser to github.com and back to a callback
  URL, so we register an OAuth App.
- **Webhooks** — GitHub delivers pushes to a public URL, so we tunnel with ngrok.

## What you need

- A running PostgreSQL (the app defaults to `postgres`/`postgres` on localhost).
- A GitHub account and a **repository you own that contains a static site** —
  an `index.html` at the repo root is enough. The repo can be public or private.
- [ngrok](https://ngrok.com/download) installed.

## 1. Set up the database and start ngrok

```bash
mix setup                 # deps, create db, migrate, build assets
ngrok http 4000           # in a second terminal — copy the https URL it prints
```

ngrok prints a forwarding URL like `https://abc123.ngrok-free.app`. Keep this
terminal open; the URL changes each time you restart ngrok (on the free plan).

## 2. Register a GitHub OAuth App

Go to **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**
(<https://github.com/settings/developers>) and set:

| Field                        | Value                                          |
| ---------------------------- | ---------------------------------------------- |
| Application name             | `Pagedock (local)` (anything)                  |
| Homepage URL                 | `http://localhost:4000`                        |
| Authorization callback URL   | `http://localhost:4000/auth/github/callback`   |

Create it, then **generate a client secret**. Copy the **Client ID** and
**Client secret**.

> The callback URL must match exactly. We drive OAuth on `localhost` (the
> browser can reach it); only *webhooks* need the tunnel.

## 3. Export environment variables and start the server

```bash
export GITHUB_CLIENT_ID=your_client_id
export GITHUB_CLIENT_SECRET=your_client_secret
export WEBHOOK_BASE_URL=https://abc123.ngrok-free.app   # your ngrok https URL, no trailing slash

mix phx.server
```

- `WEBHOOK_BASE_URL` is what gets baked into the webhook GitHub registers, so
  deliveries route through ngrok to your machine.
- `CLOAK_KEY` is optional locally (dev uses a fixed key to encrypt stored
  tokens); set your own in production.

## 4. Create an account and connect GitHub

1. Open <http://localhost:4000> and **Sign up** (email + password or magic link),
   or use **Sign in with GitHub** on the login page.
2. Go to **Settings** (top-right) → **GitHub** card → **Connect GitHub**, or just
   go to `/sites/new` and click **Connect GitHub** on the prompt.
3. Authorize the app. It requests `user:email`, `repo`, and `admin:repo_hook`
   (the last is needed to register the push webhook).

## 5. Link a repository as a site

1. Go to **Sites → New site** (`/sites/new`).
2. Pick your static-site repo from the dropdown, give the site a name, and choose
   an address slug (e.g. `demo`). Submit.
3. On success the app registers a **push webhook** on the repo pointing at
   `WEBHOOK_BASE_URL/webhooks/github/<site_id>`. You can confirm it under the
   repo's **Settings → Webhooks** on GitHub — a green check means the initial
   ping was delivered through your tunnel.

## 6. Deploy

You have two ways to trigger a deploy:

- **Deploy now** — on the site page (`/sites/<id>`), click **Deploy now**. This
  fetches the current default branch and publishes it immediately — no push
  required. Great for the first deploy.
- **Push** — push a commit to the repo's default branch. GitHub delivers the
  webhook → the app verifies the signature → enqueues a deploy.

Either way, watch the server logs: you'll see the `POST /webhooks/github/<id>`
(for a push) and the `DeployWorker` running. The site page lists deployments
with their status (`pending → building → success`).

## 7. View the served site

Deployed files are served at **`<slug>.localhost:4000`**:

```
http://demo.localhost:4000
```

Chrome and Firefox resolve `*.localhost` to `127.0.0.1` automatically. If your
browser or OS doesn't, either add an `/etc/hosts` entry, or test with curl:

```bash
curl -H "Host: demo.localhost" http://127.0.0.1:4000/
```

## Troubleshooting

- **Repo dropdown is empty / "Connect GitHub first"** — you haven't connected
  GitHub, or the token lacks `repo` scope. Disconnect and reconnect from Settings.
- **Webhook shows a red X on GitHub** — `WEBHOOK_BASE_URL` is wrong or ngrok
  isn't running. Fix it, then re-link the site (delete and recreate) so a fresh
  webhook is registered, or edit the hook URL on GitHub. Use ngrok's inspector at
  <http://127.0.0.1:4040> to see deliveries.
- **Push doesn't deploy** — only pushes to the site's **default branch** deploy;
  other branches and branch deletions are acknowledged and ignored.
- **Deploy fails** — check the site page's deployment status and the server logs.
  Common causes: the branch has no files, or the GitHub token was revoked.
- **`<slug>.localhost` won't load** — see the curl fallback above; also confirm
  the deploy reached `success` (an undeployed site returns 404 "not deployed").

## How it maps to the code

- OAuth + linking: `PageDockWeb.GithubAuthController`, `PageDock.Github`
- Webhook intake + signature check: `PageDockWeb.GithubWebhookController`
- Deploy job: `PageDock.Deployments.DeployWorker` → `PageDock.Deployments.Storage`
- Serving `<slug>.<host>`: `PageDockWeb.SiteServer`
- Host/root/tunnel config: `config :page_dock, :sites` (see `config/*.exs`)
