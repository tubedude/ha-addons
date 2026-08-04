# Tracking upstream

Forked from `home-assistant/addons` → `mosquitto`, version **7.1.0**.

## Updating

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/home-assistant/addons.git
cd addons && git sparse-checkout set mosquitto
```

Copy over the tree and **re-apply these three changes**:

1. **`Dockerfile`** — the `# --- Tailscale ---` block, immediately before
   `COPY rootfs /`. It has to come *after* the `apt-get purge`, otherwise the
   binaries get swept away with the build dependencies.

2. **`config.yaml`** — `slug: mosquitto-ts`; drop the `image:` line for local
   builds (or point it at your registry, see `build-and-push.sh`); add the three
   `tailscale_*` entries to both `options` and `schema`.

3. **`build.yaml`** — the `TAILSCALE_VERSION` arg.

`rootfs/etc/services.d/tailscaled/` is pure addition — nothing upstream is
touched by it.

## Deliberately NOT modified

`rootfs/usr/share/tempio/mosquitto.gtpl` — upstream already emits
`listener 8884 / protocol websockets` with `require_certificate`. Editing it
would create a merge conflict on every update for no benefit.

## Notes from setting this up

- The add-on slug **must not contain an underscore**, and the directory under
  `/addons/` must match the slug. With `mosquitto_ts` the Supervisor silently
  ignored the folder — no error in the logs, the add-on simply never appeared
  in the store.
- Files copied from macOS carry `._*` AppleDouble siblings. They break the
  build. `find . -name '._*' -delete` after extracting.
- Ownership must be `root:root`; a tar from another machine preserves foreign
  UIDs.
