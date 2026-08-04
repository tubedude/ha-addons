# Rastreamento do upstream

Fork de `home-assistant/addons` → `mosquitto`, na versão **7.1.0**.

## Como atualizar

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/home-assistant/addons.git
cd addons && git sparse-checkout set mosquitto
```

Copie por cima e **reaplique as três mudanças**:

1. **`Dockerfile`** — bloco `# --- Tailscale ---` antes de `COPY rootfs /`
   (precisa vir depois do `apt-get purge`, senão é removido junto)
2. **`config.yaml`** — `slug: mosquitto_ts`, remover a linha `image:`
   (sem ela o Supervisor compila local), e as 3 opções `tailscale_*`
   em `options` e `schema`
3. **`build.yaml`** — arg `TAILSCALE_VERSION`

`rootfs/etc/services.d/tailscaled/` é só adição — nada do upstream é tocado.

## O que deliberadamente NÃO foi modificado

`rootfs/usr/share/tempio/mosquitto.gtpl` — o template do upstream já emite
`listener 8884 / protocol websockets` com `require_certificate`. Alterá-lo
criaria conflito a cada atualização sem necessidade.
