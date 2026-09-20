# Deploying Pagedock with Caddy (manual, single box)

A single-box production setup on a Hetzner Cloud server: the Phoenix release,
PostgreSQL, and **Caddy** as the TLS-terminating reverse proxy, all wired up by
hand (no PaaS). Caddy serves both the dashboard (`pagedock.eu`) and every user
site (`<slug>.pagedock.eu`) — the app decides which is which.

> Prefer a git-push UI over hand-rolling this? See
> [Deploying with Coolify](deploy_coolify.md).

```
            :443 / :80
   Internet ───────────► Caddy ──► 127.0.0.1:4000  Phoenix (Bandit)
                          │                          ├─ dashboard + API (router)
                          │                          └─ SiteServer plug → /var/lib/pagedock/deploys/<slug>/
                          └─ on-demand TLS, "ask" → /internal/tls-check
                                                     PostgreSQL (localhost)
```

Everything stays on one EU machine: files, database, and TLS.

---

## 0. Prerequisites

- A domain (`pagedock.eu`) whose DNS you control.
- A GitHub **OAuth App** for production (see step 8).
- These app-specific env vars (details in step 6):
  `PHX_SERVER`, `PORT`, `PHX_HOST`, `SECRET_KEY_BASE`, `DATABASE_URL`,
  `CLOAK_KEY`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`,
  `GITHUB_REDIRECT_URI`, `WEBHOOK_BASE_URL`, `DEPLOY_ROOT`.

> **Keep `CLOAK_KEY` safe and stable.** It decrypts stored GitHub tokens
> ([config/runtime.exs](../config/runtime.exs)). Losing it means every user must
> reconnect GitHub; rotating it needs a re-encryption migration.

---

## 1. Create the server

In the Hetzner Cloud console:

- **Location:** any EU region (Helsinki, Falkenstein, Nuremberg) — matches the EU-hosting promise.
- **Image:** Ubuntu 24.04 LTS.
- **Type:** CX22 (x86) or CAX11 (ARM) is plenty to start.
- Add your SSH key.

Then, as root:

```bash
adduser --disabled-password --gecos "" pagedock
usermod -aG sudo pagedock
rsync --archive --chown=pagedock:pagedock ~/.ssh /home/pagedock

# Firewall: SSH + HTTP + HTTPS only
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw --force enable
```

Log back in as `pagedock` for the rest.

---

## 2. DNS

Point both the apex and the wildcard at the server IP (A for IPv4, AAAA for the
IPv6 Hetzner assigns):

| Type | Name             | Value            |
| ---- | ---------------- | ---------------- |
| A    | `pagedock.eu`    | `<server IPv4>`  |
| AAAA | `pagedock.eu`    | `<server IPv6>`  |
| A    | `*.pagedock.eu`  | `<server IPv4>`  |
| AAAA | `*.pagedock.eu`  | `<server IPv6>`  |

The wildcard is what makes `<slug>.pagedock.eu` resolve for every site.

---

## 3. PostgreSQL

```bash
sudo apt update
sudo apt install -y postgresql
sudo -u postgres psql <<'SQL'
CREATE USER pagedock WITH PASSWORD 'CHANGE_ME_STRONG';
CREATE DATABASE pagedock_prod OWNER pagedock;
SQL
```

Your `DATABASE_URL` becomes `ecto://pagedock:CHANGE_ME_STRONG@localhost/pagedock_prod`.

---

## 4. Erlang & Elixir

Match the versions the app is built with (Erlang/OTP 27, Elixir 1.18). `asdf`
keeps them pinned:

```bash
sudo apt install -y build-essential autoconf m4 libncurses-dev libssl-dev \
  automake libwxgtk3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev \
  unzip curl git

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc && source ~/.bashrc

asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.3
asdf install elixir 1.18.1-otp-27
asdf global erlang 27.3
asdf global elixir 1.18.1-otp-27

mix local.hex --force && mix local.rebar --force
```

---

## 5. Get the code

```bash
sudo mkdir -p /opt/pagedock && sudo chown pagedock:pagedock /opt/pagedock
git clone https://github.com/<you>/page_dock.git /opt/pagedock/current
```

---

## 6. Environment file

Create `/etc/pagedock.env` (root-owned, readable by the service):

```bash
sudo install -m 600 /dev/null /etc/pagedock.env
sudo tee /etc/pagedock.env >/dev/null <<'ENV'
PHX_SERVER=true
PORT=4000
PHX_HOST=pagedock.eu
SECRET_KEY_BASE=REPLACE_ME
DATABASE_URL=ecto://pagedock:CHANGE_ME_STRONG@localhost/pagedock_prod
POOL_SIZE=10
CLOAK_KEY=REPLACE_ME
GITHUB_CLIENT_ID=REPLACE_ME
GITHUB_CLIENT_SECRET=REPLACE_ME
GITHUB_REDIRECT_URI=https://pagedock.eu/auth/github/callback
WEBHOOK_BASE_URL=https://pagedock.eu
DEPLOY_ROOT=/var/lib/pagedock/deploys
# Email — Brevo API (magic links, confirmations)
BREVO_API_KEY=REPLACE_ME
MAIL_FROM=hello@pagedock.eu
MAIL_FROM_NAME=Pagedock
ENV
```

For email: create an **API key** in Brevo (SMTP & API → API Keys) as
`BREVO_API_KEY`, and verify `hello@pagedock.eu` as a sender in Brevo. Prod won't
start until `BREVO_API_KEY` is set.

Generate the two secrets:

```bash
cd /opt/pagedock/current
mix phx.gen.secret                                   # -> SECRET_KEY_BASE
mix run -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'   # -> CLOAK_KEY
```

> `DEPLOY_ROOT` **must** be an absolute path outside the release (published site
> files must survive upgrades). `/var/lib/pagedock/deploys` is created for you by
> the systemd `StateDirectory` in step 9.

---

## 7. Build the release

Run as `pagedock` from `/opt/pagedock/current`, loading the env so the build and
migrations can reach the database:

```bash
set -a; . /etc/pagedock.env; set +a

mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy      # tailwind + esbuild + digest
MIX_ENV=prod mix ecto.migrate       # runs all migrations incl. Oban
MIX_ENV=prod mix release --overwrite
```

The release binary lands at
`/opt/pagedock/current/_build/prod/rel/page_dock/bin/page_dock`.

---

## 8. GitHub OAuth App (production)

At <https://github.com/settings/developers> → New OAuth App:

- **Homepage URL:** `https://pagedock.eu`
- **Authorization callback URL:** `https://pagedock.eu/auth/github/callback`

Put the Client ID/Secret into `/etc/pagedock.env`. `WEBHOOK_BASE_URL=https://pagedock.eu`
means webhooks Pagedock registers on repos deliver to
`https://pagedock.eu/webhooks/github/<site_id>` — reachable in production (no
tunnel needed, unlike local dev).

---

## 9. Run it under systemd

```bash
sudo tee /etc/systemd/system/pagedock.service >/dev/null <<'UNIT'
[Unit]
Description=Pagedock
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=exec
User=pagedock
Group=pagedock
EnvironmentFile=/etc/pagedock.env
WorkingDirectory=/opt/pagedock/current
ExecStart=/opt/pagedock/current/_build/prod/rel/page_dock/bin/page_dock start
Restart=on-failure
RestartSec=5
# Creates /var/lib/pagedock (== DEPLOY_ROOT parent), owned by the service user
StateDirectory=pagedock

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now pagedock
sudo systemctl status pagedock
curl -s localhost:4000/healthz    # -> ok
```

---

## 10. Caddy (TLS + reverse proxy)

Install Caddy:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

`/etc/caddy/Caddyfile`:

```caddyfile
{
    email admin@pagedock.eu
    # Gate on-demand certificate issuance: Caddy asks the app whether a host is
    # real before minting a cert, so we never issue for random hostnames.
    on_demand_tls {
        ask http://127.0.0.1:4000/internal/tls-check
        interval 2m
        burst 5
    }
}

# Dashboard + API + webhooks (known host → normal ACME HTTP challenge)
pagedock.eu {
    reverse_proxy 127.0.0.1:4000
}

# Every user site: <slug>.pagedock.eu. Certificates are issued on first request,
# authorized by the ask endpoint above. Unknown hosts get a 403 and no cert.
https:// {
    tls {
        on_demand
    }
    reverse_proxy 127.0.0.1:4000
}
```

```bash
sudo systemctl reload caddy
```

Now verify with a real site. Visit `https://pagedock.eu`, create an account,
connect GitHub, and **New site** → link `hireordo/landing` (branch `main`) as
`ordo-landing`. Push (or click **Deploy now**), then open
**`https://ordo-landing.pagedock.eu`** — Caddy fetches a cert for it on the first
hit and the app serves it from `$DEPLOY_ROOT/ordo-landing/`.

> **Alternative: wildcard certificate.** If you'd rather issue one
> `*.pagedock.eu` cert instead of per-subdomain on-demand, use a Caddy build with
> your DNS provider's plugin and the DNS-01 challenge. On-demand is simpler and
> needs no DNS API token, so it's the default here.

---

## 11. Redeploying a new version

```bash
sudo -iu pagedock
cd /opt/pagedock/current
set -a; . /etc/pagedock.env; set +a
git pull
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix ecto.migrate
MIX_ENV=prod mix release --overwrite
exit
sudo systemctl restart pagedock
```

Published sites in `DEPLOY_ROOT` are untouched by a redeploy. (For zero-downtime
you'd build to a release dir and flip a symlink, but restart is fine to start.)

---

## 12. Backups & recovery

- **Database** (the source of truth — users, sites, encrypted tokens, deploy
  history). Nightly `pg_dump`:

  ```bash
  echo '0 3 * * * pagedock pg_dump pagedock_prod | gzip > /var/backups/pagedock-$(date +\%F).sql.gz' | sudo tee /etc/cron.d/pagedock-backup
  ```

- **`CLOAK_KEY` and `SECRET_KEY_BASE`** — store off-box (a password manager). A DB
  backup is useless for GitHub tokens without the Cloak key.
- **`DEPLOY_ROOT`** — nice to back up, but reproducible: any site can be
  re-published from GitHub via the site's **Deploy now** button.

---

## 13. Operations cheat-sheet

| Task            | Command                                             |
| --------------- | --------------------------------------------------- |
| Logs            | `journalctl -u pagedock -f`                          |
| Restart app     | `sudo systemctl restart pagedock`                    |
| Remote console  | `.../bin/page_dock remote`                            |
| Health          | `curl -s localhost:4000/healthz`                     |
| Caddy logs      | `journalctl -u caddy -f`                             |
| DB console      | `psql pagedock_prod`                                 |

---

## How this maps to the code

- Product vs. site routing: `PageDockWeb.SiteServer` (host-based, runs before the
  router in [endpoint.ex](../lib/page_dock_web/endpoint.ex)).
- TLS "ask" + health: `PageDockWeb.OpsController` (`/internal/tls-check`,
  `/healthz`) backed by `PageDock.Sites.servable_host?/1`.
- Runtime config & env vars: [config/runtime.exs](../config/runtime.exs).
- Local end-to-end testing (dev, with ngrok): [local_end_to_end.md](local_end_to_end.md).
```
