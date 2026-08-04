# Mosquitto broker + Tailscale

Fork do add-on oficial [`mosquitto`](https://github.com/home-assistant/addons/tree/master/mosquitto)
do Home Assistant, com Tailscale embutido.

## Por que este fork existe

O objetivo é um só: **um cliente que não pode rodar Tailscale precisa alcançar o
broker MQTT de fora da rede de casa.**

No caso concreto, esse cliente é a central multimídia de um Geely (Android
Automotive). Ela não roda cliente VPN nenhum — o ROM não inclui
`com.android.vpndialogs`, então qualquer app de VPN morre com
`ActivityNotFoundException` no instante em que pede permissão. E a rede de casa
está atrás de CGNAT, então não há porta a abrir para um proxy reverso comum
(NGINX + Let's Encrypt não recebem conexão de fora).

O Tailscale **Funnel** resolve os dois problemas ao mesmo tempo: é um túnel de
*saída* (fura o CGNAT) e o cliente do outro lado não precisa de Tailscale — fala
TLS comum com um endereço público.

### Por que dentro do add-on, e não em outra máquina

Funciona publicar o Funnel de qualquer nó do tailnet que enxergue o broker. Mas
isso torna esse nó infraestrutura: se ele desligar, o acesso remoto cai. Um PC
que se desliga não é bom lugar para isso. Aqui o Funnel vive junto do próprio
broker, no mesmo container, e sobe com ele.

### Por que Funnel em modo TCP

Esta é a razão técnica que motivou o fork em vez de uma solução externa.

Com `tailscale funnel` em modo HTTP, o **TLS termina na borda do Tailscale** e o
backend recebe HTTP puro. O broker nunca vê o certificado do cliente, então
`require_certificate` não tem efeito — a autenticação fica restrita a
usuário/senha, numa porta exposta à internet.

Com `funnel --tcp`, o TLS termina **no listener 8884 do próprio mosquitto**.
O broker enxerga o certificado do cliente e `require_certificate: true` volta a
valer de ponta a ponta.

## O que muda em relação ao upstream

Três arquivos, nada mais:

| arquivo | mudança |
|---|---|
| `Dockerfile` | instala `tailscale`/`tailscaled` **depois** do purge do build |
| `config.yaml` | `slug` próprio, remove `image:` (compila local), 3 opções novas |
| `rootfs/etc/services.d/tailscaled/` | serviço s6 que sobe o daemon e publica o Funnel |

O `mosquitto.gtpl` **não foi tocado** — o upstream já gera
`listener 8884 / protocol websockets` com `require_certificate`. A capacidade
sempre esteve lá; faltava o túnel.

Manter o fork em dia é reaplicar essas três mudanças. O add-on upstream muda
pouco (meses entre releases).

## Opções

```yaml
tailscale_authkey: tskey-auth-...    # gerada no admin console (reusable)
tailscale_hostname: mosquitto        # nome no tailnet
tailscale_funnel_port: 8443          # só 443, 8443 ou 10000 são aceitas
```

Sem `tailscale_authkey`, o Tailscale fica desativado e o add-on se comporta
exatamente como o oficial.

## Pré-requisitos no tailnet

1. **HTTPS habilitado** no admin console (DNS → HTTPS Certificates)
2. **Atributo `funnel`** na policy do tailnet:
   ```json
   "nodeAttrs": [
     { "target": ["autogroup:member"], "attr": ["funnel"] }
   ]
   ```
3. **Certificado presente** em `/ssl` (`certfile`/`keyfile`) — sem ele o
   listener 8884 não sobe e não há o que publicar

## Endereço resultante

```
wss://<tailscale_hostname>.<tailnet>.ts.net:8443/
```

No app cliente, use esse endereço como fallback do endereço da LAN. O cliente
MQTT (Paho, por exemplo) aceita uma lista e tenta em ordem: em casa vai pelo
IP local, fora vai pelo Funnel.

## Segurança

Isto **expõe o broker à internet pública**. Duas medidas valem a pena:

- **`require_certificate: true`** — o motivo de todo este fork. Cada cliente
  precisa de um certificado assinado pela sua CA; senha vazada não basta.
- **Usuário dedicado com ACL** restrita aos tópicos daquele cliente, para que um
  comprometimento não dê acesso ao broker inteiro.

Se você não for usar client certs, a exposição fica protegida só por senha — e
aí um Funnel HTTP simples, sem fork, teria o mesmo efeito com menos manutenção.

## Falhas isoladas

Se o `tailscaled` morrer, o add-on **não cai**: o serviço `finish` retorna 0 e o
mosquitto continua servindo a LAN normalmente. Perder acesso remoto é melhor que
perder o broker.
