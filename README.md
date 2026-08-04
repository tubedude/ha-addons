# Trevisan Home Assistant add-ons

## Installation

Settings → Add-ons → Add-on Store → ⋮ → **Repositories**, then add:

```
https://github.com/tubedude/ha-addons
```

## Add-ons

### [Mosquitto broker + Tailscale](./mosquitto-ts)

The official Mosquitto add-on with Tailscale built in, so the broker can publish
itself over Tailscale Funnel.

It exists for one reason: to let a client that **cannot run Tailscale** reach the
MQTT broker from outside the home network — in this case a car head unit whose
Android ROM ships without `com.android.vpndialogs`, so no VPN app can run, on a
home network behind CGNAT where no port can be forwarded.

Funnel in `--tcp` mode keeps TLS terminating at mosquitto itself, which is what
makes `require_certificate` work end to end. See the [add-on README](./mosquitto-ts/README.md).
