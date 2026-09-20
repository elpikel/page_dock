# Deploying Pagedock with Coolify

[Coolify](https://coolify.io) is an open-source, self-hosted PaaS (a Heroku /
Netlify / Render alternative you run on your own server). It replaces most of the
manual [Caddy runbook](deploy_caddy.md): server bootstrap, systemd, the
Postgres install, and the reverse proxy + TLS — you deploy from git in its UI and
manage env vars, databases, backups, and logs there.

Pagedock is **not** a normal single-domain app, so there are exactly two things
you must get right with Coolify: **wildcard subdomain TLS** and a **persistent
volume** for published site files. Everything else is standard.

```
                      Coolify (Traefik proxy, TLS)
   Internet ─── :443 ──────────────┬──────────────► app container :4000
                                    │                 ├─ dashboard + API (router)
     pagedock.eu   (normal cert)    │                 └─ SiteServer → $DEPLOY_ROOT/<slug>/
     *.pagedock.eu (wildcard cert) ─┘                 PostgreSQL (Coolify resource)
                                                       persistent volume → $DEPLOY_ROOT
```

---

## Why the two special requirements

- **Wildcard TLS.** Coolify's proxy issues a certificate per **domain you
  configure on a service**. It does not know about `foo.pagedock.eu` that the app
  creates at runtime, and it has **no equivalent of Caddy's on-demand "ask"
  endpoint**. So you issue **one `*.pagedock.eu` wildcard certificate** via the
  **DNS-01** challenge (HTTP-01 can't do wildcards). Traefik then terminates TLS
  for every subdomain and forwards to the container; the app's
  `PageDockWeb.SiteServer` picks the right site. The `/internal/tls-check`
  endpoint from the Caddy setup is **not used** here (harmless to leave in).

- **Persistent volume.** Containers are ephemeral. `DEPLOY_ROOT`
  (`/var/lib/pagedock/deploys` on the Hetzner box) must be a **mounted volume**,
  or every redeploy wipes all published sites.

---

## Prerequisites

- A server (Hetzner, EU region) you control. Coolify installs onto it.
- DNS control for `pagedock.eu`, **with a DNS provider Traefik supports** (needed
  for the wildcard cert) and an API token for it.
- A **Dockerfile** — already in the repo (generated with
  `mix phx.gen.release --docker`), along with `rel/overlays/bin/server` and
  `rel/overlays/bin/migrate` for release-based migrations, and
  `PageDock.Release`. Coolify builds this image directly.
- A production **GitHub OAuth App** (see the [Caddy runbook, step 8](deploy_caddy.md#8-github-oauth-app-production)).

---

## 1. Install Coolify

On a fresh Ubuntu 24.04 server (see the official docs for the current command):

```bash
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

Open `http://<server-ip>:8000`, create the admin account. Coolify runs itself in
Docker and can deploy onto the same server ("localhost" destination) or others.

Open ports **80** and **443** (public) and **8000** for the dashboard (ideally
behind its own domain/IP allowlist rather than public).

---

## 2. DNS

Point apex and wildcard at the server:

| Type | Name            | Value           |
| ---- | --------------- | --------------- |
| A    | `pagedock.eu`   | `<server IPv4>` |
| AAAA | `pagedock.eu`   | `<server IPv6>` |
| A    | `*.pagedock.eu` | `<server IPv4>` |
| AAAA | `*.pagedock.eu` | `<server IPv6>` |

---

## 3. PostgreSQL

**New Resource → Database → PostgreSQL.** Coolify provisions it and shows a
connection string. Use its **internal** URL (container-network hostname) as
`DATABASE_URL`. Turn on **scheduled backups** (Coolify can push DB dumps to S3).

---

## 4. The application

**New Resource → Application →** connect the GitHub repo (or a public repo URL).

- **Build pack:** Dockerfile.
- **Port (exposed):** `4000`.
- **Health check path:** `/healthz` (the app's liveness endpoint).
- Optionally enable **auto-deploy on push** (Coolify registers its own repo
  webhook) so `git push` ships a new version.

---

## 5. Environment variables

Set these on the application (same set as the Hetzner deploy; see
[config/runtime.exs](../config/runtime.exs)):

```
PHX_SERVER=true
PORT=4000
PHX_HOST=pagedock.eu
SECRET_KEY_BASE=<mix phx.gen.secret>
DATABASE_URL=<internal URL from the Coolify Postgres resource>
POOL_SIZE=10
CLOAK_KEY=<base64 32 bytes>
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
GITHUB_REDIRECT_URI=https://pagedock.eu/auth/github/callback
WEBHOOK_BASE_URL=https://pagedock.eu
DEPLOY_ROOT=/data/deploys
BREVO_API_KEY=<brevo api key>
MAIL_FROM=hello@pagedock.eu
MAIL_FROM_NAME=Pagedock
```

Email goes through the **Brevo API**: create an API key in Brevo (SMTP & API →
API Keys) as `BREVO_API_KEY`, and verify `hello@pagedock.eu` as a sender. Prod
won't boot until `BREVO_API_KEY` is set.

Generate the secrets locally:

```bash
mix phx.gen.secret                                                  # SECRET_KEY_BASE
mix run -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))' # CLOAK_KEY
```

> **`CLOAK_KEY` must be kept off-box and never change** — it decrypts stored
> GitHub tokens. A DB backup is useless for tokens without it.

---

## 6. Domains + wildcard TLS  ← the important part

On the application's **Domains**, add both:

```
https://pagedock.eu
https://*.pagedock.eu
```

`pagedock.eu` gets a normal Let's Encrypt cert automatically. `*.pagedock.eu`
needs a **wildcard certificate via the DNS-01 challenge**, which means giving
Traefik your DNS provider's API credentials.

This is the one step whose exact UI changes between Coolify versions — consult
Coolify's docs for **"wildcard domains / DNS challenge / Traefik DNS resolver."**
The essential requirement, however you configure it, is:

- Traefik solves DNS-01 with your provider token and obtains `*.pagedock.eu`.
- Both `pagedock.eu` and `*.pagedock.eu` route to this container on port `4000`.

Once that's in place, `https://<slug>.pagedock.eu` is covered by the wildcard cert
and served by the app — no per-host issuance needed.

> **No DNS provider API?** Then Coolify/Traefik can't do wildcards, and you're
> back to Caddy's on-demand approach ([Caddy runbook, step 10](deploy_caddy.md#10-caddy-tls--reverse-proxy)) —
> which is exactly why that endpoint exists.

---

## 7. Persistent storage for published sites

Add **Persistent Storage** to the application:

- **Mount path:** `/data` (a Docker volume).
- Set `DEPLOY_ROOT=/data/deploys` (as in step 5) so the app writes published site
  files onto the volume.

Without this, `DeployWorker` writes into the container's ephemeral filesystem and
every redeploy/restart drops all live sites.

---

## 8. Migrations

Nothing to configure — the image **migrates on boot**. Its `CMD` runs
`/app/bin/migrate && /app/bin/server`, so every container start applies pending
migrations before serving; a failed migration aborts startup (Ecto's migration
lock makes this safe across restarts and multiple instances). Oban's tables are
created by these same migrations.

If you'd rather migrate as a separate step, remove the `bin/migrate` from the
Dockerfile `CMD` and set a Coolify **Pre-deployment command** of `/app/bin/migrate`
instead.

---

## 9. Deploy & verify with a real site

Hit **Deploy**. Coolify builds the image and starts the container, which migrates
on boot, then Traefik wires up TLS.

Then walk one site through end to end — using the **Ordo landing page** as the
example:

1. Visit `https://pagedock.eu`, create an account, **Connect GitHub**.
2. **New site** → pick `hireordo/landing`, branch `main`, name it `ordo-landing`.
   Pagedock registers a push webhook at `https://pagedock.eu/webhooks/github/<id>`.
3. Push to `main` (or click **Deploy now**). `DeployWorker` pulls that commit,
   extracts it into `$DEPLOY_ROOT/ordo-landing/` on the volume, and marks the
   deploy **Live**.
4. Open **`https://ordo-landing.pagedock.eu`** — served from the volume under the
   `*.pagedock.eu` wildcard cert.

---

## Coolify vs. the Caddy runbook

| | [Caddy runbook](deploy_caddy.md) | Coolify |
| --- | --- | --- |
| App lifecycle | Manual `mix release` + systemd | Git-push UI, rollbacks, logs, auto-deploy |
| Runtime | Native release on host | Docker container (Dockerfile) |
| Site TLS | On-demand per subdomain (HTTP-01, no DNS token) | **Wildcard cert (DNS-01, needs provider token)** |
| `/internal/tls-check` | Used | Not used |
| `DEPLOY_ROOT` persistence | Host dir (`StateDirectory`) | **Mounted volume** |
| Postgres | `apt install` + manual | Managed resource + backups |
| Migrations | `mix ecto.migrate` from checkout | on boot (Dockerfile `CMD`) |

Coolify trades "a Dockerfile + one DNS API token" for a much nicer deploy/ops
experience. Good fit if you want a UI and push-to-deploy; the Caddy path is
leaner if you want zero extra moving parts and no DNS provider dependency.

---

## Gotchas

- **Wildcard cert is the make-or-break.** Everything hinges on Traefik getting
  `*.pagedock.eu` via DNS-01. Test a fresh subdomain end to end before launch.
- **Volume before first real site.** Add the `/data` volume and `DEPLOY_ROOT`
  before anyone links a site, or early deploys land on ephemeral storage.
- **Health check → `/healthz`.** Don't point it at a DB-touching path.
- **Keep `CLOAK_KEY` / `SECRET_KEY_BASE`** in a password manager, not only in
  Coolify.

## Related

- [Local end-to-end testing (dev + ngrok)](local_end_to_end.md)
- [Manual Caddy runbook](deploy_caddy.md)
