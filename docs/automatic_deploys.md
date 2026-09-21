# Automatic deploys — making every site go live on its own

The goal: a user links a GitHub repo and the site is live at
`https://<slug>.pagedock.eu` — deployed, routed, and HTTPS-secured — **with no
per-site setup**. This doc explains what's already automatic in the app and the
one infrastructure piece you must set up (wildcard routing + TLS) to close the
loop.

---

## What's already automatic (in the app — nothing to configure)

- **On link** (`SiteLive.Form`): the first deploy is enqueued immediately, and a
  GitHub **push webhook** is registered on the repo (`Sites.register_webhook`).
- **On push**: GitHub calls `POST /webhooks/github/:site_id`; the HMAC signature
  is verified; a push to the site's default branch enqueues a deploy.
- **Deploy** (`DeployWorker`): fetches the commit tarball, extracts it, and
  atomically publishes to `DEPLOY_ROOT/<slug>/` on the persistent volume.
- **Serving** (`PageDockWeb.SiteServer`): serves `<slug>.<sites_host>` straight
  from disk, deciding which site by the subdomain.

So the **deploy and serve halves are fully automatic**. The only thing that isn't
automatic out of the box is **TLS + routing for brand-new subdomains**, because
that lives in your DNS + reverse proxy, not the app.

---

## The one manual-vs-automatic decision: subdomain TLS

A request to `https://<slug>.pagedock.eu` needs two things from the proxy:

1. **Routing** — forward that host to the app container.
2. **A certificate** — a valid TLS cert for that exact host.

A **wildcard** (`*.pagedock.eu`) is what makes *both* automatic for every present
and future site. But a wildcard certificate can only be issued via the **DNS-01**
ACME challenge, which requires the proxy to create a DNS TXT record through your
DNS provider's **API**.

> **Blocker:** `pagedock.eu`'s DNS is at **home.pl**, which has no API that
> Traefik/lego supports — so DNS-01 (and therefore the wildcard cert) is
> impossible while DNS lives there. You must move the domain's **nameservers** to
> a supported provider. (The domain stays registered at home.pl; only who answers
> DNS lookups changes, and traffic still goes straight to the EU server.)

---

## Setup: automatic wildcard (routing + TLS)

### 1. Move DNS to a DNS-01-capable provider

**Recommended: Hetzner DNS** — EU-based (matches the hosting promise) and the
server is already on Hetzner.

1. [dns.hetzner.com](https://dns.hetzner.com) → **Add zone** `pagedock.eu`. It
   shows 3 nameservers.
2. In **home.pl** → domain settings → change the **nameservers** to Hetzner's.
   (This is the only home.pl change.)
3. In Hetzner DNS, add:
   - `A` · `@` · `37.27.242.184`
   - `A` · `*` · `37.27.242.184`
4. **API Tokens** → create a token with DNS write access. Save it.

Propagation takes a few hours. Verify:
```bash
dig +short pagedock.eu           # 37.27.242.184
dig +short anything.pagedock.eu  # 37.27.242.184 (wildcard)
```

> **Alternative: Cloudflare** — fastest and best-supported, but US-based. If you
> use it, keep records in **"DNS only" (grey cloud)** so traffic doesn't route
> through Cloudflare's edge (which would break the EU-only story). Token env is
> `CF_DNS_API_TOKEN`.

### 2. Point the app at the wildcard in Coolify

App → **Configuration → Domains**:
```
https://pagedock.eu
https://*.pagedock.eu
```

### 3. Give Traefik the DNS-01 resolver

This is the fiddly, **Coolify-version-specific** part — configure Coolify's
Traefik proxy to solve DNS-01 with your provider. Conceptually you need:

- A **certificate resolver** using the DNS challenge, e.g. (Traefik static config):

  ```yaml
  certificatesResolvers:
    letsencrypt:
      acme:
        email: admin@pagedock.eu
        storage: /traefik/acme.json
        dnsChallenge:
          provider: hetzner        # or cloudflare
  ```

- The provider's **API token as an environment variable on the `coolify-proxy`
  container**, so lego can create the TXT record:

  ```
  HETZNER_API_KEY=<token>          # or CF_DNS_API_TOKEN=<token>
  ```

- The app's router configured to use that resolver and the `*.pagedock.eu` SAN.

In Coolify this is done under **Servers → Proxy** (edit the Traefik config /
environment) — check the current Coolify docs for "wildcard domain / DNS
challenge", since the exact UI moves between versions. Restart the proxy after.

### 4. Verify

Link a fresh site (or open the existing one). Within a minute:
```bash
curl -vI https://<slug>.pagedock.eu 2>&1 | grep -i issuer   # → Let's Encrypt
```
A valid Let's Encrypt issuer means new sites now route **and** get HTTPS with zero
per-site work.

---

## Fallback that works today (manual, per site)

Until the wildcard is set up, a **specific** subdomain gets a valid cert via
HTTP-01 (no DNS API needed):

1. Coolify → app → **Domains**, add `https://<slug>.pagedock.eu` (a specific host,
   not `*`). Set **Direction → Redirect to non-www**.
2. **Redeploy** (full — so Coolify wires the Traefik backend for the host).
3. `https://<slug>.pagedock.eu` routes and gets a Let's Encrypt cert.

This is exactly how the first live site (`cmdarek.pagedock.eu`) was validated.
It's reliable but **manual per site**, so it doesn't scale for self-serve — the
wildcard is the real answer.

---

## Troubleshooting

| Symptom | Meaning | Fix |
| --- | --- | --- |
| `404 page not found` (plain text) | Traefik has **no route** for the host | Attach the domain (specific or wildcard) to the app |
| `no available server` | Route exists but **no backend** wired | Coolify wildcard routing is flaky — use the specific host, or **full redeploy** so labels regenerate |
| `ERR_CERT_AUTHORITY_INVALID` | Route works, but **self-signed cert** (no ACME success) | Wildcard needs DNS-01 (move DNS); or add the specific host for HTTP-01 |
| Deploy shows `failed` | The `DeployWorker` couldn't publish | Open the site page — the error is shown; common cause is the `DEPLOY_ROOT` volume not writable by `nobody` (see [deploy_coolify.md](deploy_coolify.md)) |

## Related

- [Deploying with Coolify](deploy_coolify.md)
- [Manual Caddy runbook](deploy_caddy.md) — Caddy's **on-demand TLS** is an
  alternative that needs **no DNS API** (per-subdomain certs via HTTP-01), if you
  ever move off Coolify's Traefik.
- [Local end-to-end testing](local_end_to_end.md)
