ARG BUILD_FROM
FROM $BUILD_FROM

# Install mosquitto + auth plugin
WORKDIR /usr/src
ARG LIBWEBSOCKET_VERSION
ARG MOSQUITTO_VERSION
ARG MOSQUITTO_AUTH_VERSION
RUN apt-get update \
    && apt-get install -qy --no-install-recommends \
        nginx \
        pwgen \
        build-essential \
        cmake \
        git \
        openssl \
        libssl-dev \
        libc-ares2 \
        libc-ares-dev \
        libcjson1 \
        libcjson-dev \
        libsqlite3-dev \
        xsltproc \
        docbook-xsl \
        golang-go \
    \
    # Compile and install libwebsocket
    #
    # DLWS_WITHOUT_TESTAPPS is just a workaround, see
    # https://github.com/warmcat/libwebsockets/issues/2790 for more
    && git clone --depth 1 -b "v${LIBWEBSOCKET_VERSION}" \
       https://libwebsockets.org/repo/libwebsockets \
    \
    && cd libwebsockets \
    && mkdir build \
    && cd build \
    && cmake -DLWS_WITH_EXTERNAL_POLL=ON -DLWS_WITHOUT_TESTAPPS=ON .. \
    && make install \
    && ldconfig \
    && cd ../.. \
    # Compile and install mosquitto
    && git clone --depth 1 -b "v${MOSQUITTO_VERSION}" \
       https://github.com/eclipse/mosquitto \
    \
    && cd mosquitto \
    # Disable editline used by mosquitto_ctrl
    && sed -i 's/^WITH_EDITLINE=yes/#WITH_EDITLINE=yes/' config.mk \
    # Disable REST API
    && sed -i 's/^WITH_HTTP_API=yes/#WITH_HTTP_API=yes/' config.mk \
    && make WITH_WEBSOCKETS=yes WITH_SRV=yes \
    && make install \
    && cd .. \
    # Compile and install mosquitto-go-auth
    && git clone --depth 1 -b "${MOSQUITTO_AUTH_VERSION}" \
       https://github.com/iegomez/mosquitto-go-auth \
    \
    && cd mosquitto-go-auth \
    && sed -i 's/-I\/usr\/local\/include/-I\/usr\/include/' Makefile \
    && sed -i 's/LDFLAGS := .*$/& -Wl,-unresolved-symbols=ignore-all/' Makefile \
    && make \
    && mkdir -p /usr/share/mosquitto \
    && cp -f go-auth.so /usr/share/mosquitto \
    && cp -f pw /usr/local/bin \
    \
    && apt-get purge -y --auto-remove \
        build-essential \
        git \
        cmake \
        libssl-dev \
        libc-ares-dev \
        libcjson-dev \
        libsqlite3-dev \
        xsltproc \
        docbook-xsl \
        golang-go \
    && apt-get clean \
    && rm -fr \
        /etc/logrotate.d \
        /etc/mosquitto/* \
        /etc/nginx/* \
        /usr/share/nginx \
        /usr/src/libwebsockets \
        /usr/src/mosquitto \
        /usr/src/mosquitto-go-auth \
        /var/lib/nginx/html \
        /var/www \
        /var/lib/apt/lists/* \
	/root/.cache \
	/root/go

# --- Tailscale ------------------------------------------------------------
# Why this fork: give the broker its own tailnet identity and a dedicated
# Funnel, so a client that CANNOT run Tailscale reaches MQTT from any network,
# with the home network behind CGNAT.
#
# With Funnel in TCP mode, TLS terminates at mosquitto ITSELF (listener 8884),
# so require_certificate works end to end — which is not the case when Funnel
# proxies HTTP and terminates TLS at the edge.
ARG TAILSCALE_VERSION
RUN apt-get update \
    && apt-get install -qy --no-install-recommends curl ca-certificates \
    && ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64)   TS_ARCH="amd64" ;; \
         arm64)   TS_ARCH="arm64" ;; \
         *)       echo "unsupported arch: ${ARCH}" && exit 1 ;; \
       esac \
    && curl -fsSL -o /tmp/ts.tgz \
       "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_${TS_ARCH}.tgz" \
    && tar -xzf /tmp/ts.tgz -C /tmp \
    && mv /tmp/tailscale_${TAILSCALE_VERSION}_${TS_ARCH}/tailscale /usr/local/bin/ \
    && mv /tmp/tailscale_${TAILSCALE_VERSION}_${TS_ARCH}/tailscaled /usr/local/bin/ \
    && rm -rf /tmp/ts.tgz /tmp/tailscale_${TAILSCALE_VERSION}_${TS_ARCH} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy rootfs
COPY rootfs /

WORKDIR /
