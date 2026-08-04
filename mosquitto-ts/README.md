# Mosquitto broker + Tailscale

A fork of the official Home Assistant [`mosquitto`](https://github.com/home-assistant/addons/tree/master/mosquitto)
add-on with Tailscale built in, so the broker can publish itself over Tailscale
Funnel.

## Why this fork exists

One goal: **let a client that cannot run Tailscale reach the MQTT broker from
outside the home network.**

The concrete client is a Geely head unit (Android Automotive). It cannot run any
VPN client — the ROM ships without `com.android.vpndialogs`, so every VPN app
dies with `ActivityNotFoundException` the moment it requests permission. And the
home network is behind CGNAT, so there is no port to forward for a conventional
reverse proxy (NGINX + Let's Encrypt never receive the inbound connection).

Tailscale **Funnel** solves both at once: it is an *outbound* tunnel, so CGNAT
is irrelevant, and the far side needs no Tailscale at all — it speaks ordinary
TLS to a public hostname.

### Why inside the add-on rather than on another machine

Publishing the Funnel from any tailnet node that can see the broker works — we
tested it from a WSL box. But that turns the node into infrastructure: if it
sleeps, remote access dies. A desktop that gets switched off is a poor place for
that. Here the Funnel lives next to the broker and starts with it.

### Why Funnel in TCP mode

This is the technical reason a fork was warranted rather than an external proxy.

With `tailscale funnel` in HTTP mode, **TLS terminates at Tailscale's edge** and
the backend receives plain HTTP. The broker never sees the client certificate,
so `require_certificate` has no effect — authentication collapses to
username/password on an internet-facing port.

With `funnel --tcp`, TLS terminates at **mosquitto's own listener on 8884**. The
broker sees the client certificate and `require_certificate: true` works
end to end.

(Note the distinction from `--tls-terminated-tcp`, which would put us back in
the first case.)

## What differs from upstream

Three files, nothing else:

| file | change |
|---|---|
| `Dockerfile` | installs `tailscale`/`tailscaled` **after** the build purge |
| `config.yaml` | own slug, drops `image:` for local builds, three new options |
| `rootfs/etc/services.d/tailscaled/` | s6 service that starts the daemon and publishes the Funnel |

`mosquitto.gtpl` is deliberately **untouched** — upstream already emits
`listener 8884 / protocol websockets` with `require_certificate`. The capability
was always there; only the tunnel was missing. Keeping the template pristine
means upstream updates never conflict.

Keeping the fork current means re-applying those three changes. Upstream moves
slowly (months between releases). See `UPSTREAM.md`.

## Options

```yaml
tailscale_authkey: tskey-auth-...    # generate in the admin console (reusable)
tailscale_hostname: mosquitto        # name on the tailnet
tailscale_funnel_port: "8443"        # only 443, 8443 and 10000 are allowed
```

With no `tailscale_authkey` the Tailscale side stays off and the add-on behaves
exactly like the official one.

## Tailnet prerequisites

1. **HTTPS certificates enabled** in the admin console (DNS → HTTPS Certificates)
2. **The `funnel` node attribute** in the tailnet policy:
   ```json
   "nodeAttrs": [
     { "target": ["autogroup:member"], "attr": ["funnel"] }
   ]
   ```
3. **A certificate in `/ssl`** (`certfile`/`keyfile`). Without it the 8884
   listener never starts and there is nothing to publish.

## Resulting endpoint

```
wss://<tailscale_hostname>.<tailnet>.ts.net:8443/
```

Use it as a fallback next to the LAN address. An MQTT client that accepts a
server list (Paho, for instance) will try them in order: the local IP at home,
the Funnel everywhere else.

## Building

The Dockerfile compiles libwebsockets and mosquitto from source, which is slow
on a typical Home Assistant box. Two ways to avoid that:

**Build elsewhere and pull** — build on any amd64 machine with Docker, push to a
registry, and restore the `image:` line in `config.yaml`:

```yaml
image: ghcr.io/<user>/mosquitto-ts-{arch}
```

See `build-and-push.sh`. Installing then becomes a download.

**Build on the HA box** — leave `image:` out and the Supervisor builds locally.
Simpler, but expect a long first install.

## Security

This exposes the broker to the public internet. Two measures matter:

- **`require_certificate: true`** — the reason this fork exists. Each client
  needs a certificate signed by your CA; a leaked password is not enough.
- **A dedicated user with an ACL** scoped to that client's topics, so a
  compromise does not hand over the whole broker.

If you are not going to use client certificates, a plain HTTP Funnel from any
node achieves the same reachability with no fork to maintain.

## Failure isolation

If `tailscaled` dies the add-on does **not** go down: the `finish` script exits
0 and mosquitto keeps serving the LAN. Losing remote access beats losing the
broker.
