FROM golang:alpine as builder

ARG BRANCH='tun-dev'
ENV BRANCH=$BRANCH

RUN echo "Using branch: $BRANCH"

RUN apk add --no-cache make git curl

WORKDIR /go
RUN set -eux; \
    \
    curl -L -O https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb; \
    git clone --single-branch --branch ${BRANCH} https://github.com/comzyh/clash /clash-src

WORKDIR /clash-src

RUN go mod download

COPY Makefile /clash-src/Makefile
RUN make current

FROM alpine:latest

# RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.11/main/" > /etc/apk/repositories

COPY --from=builder /clash-src/bin/clash /usr/local/bin/
COPY --from=builder /go/Country.mmdb /root/.config/clash/
COPY config.yaml /root/.config/clash/
COPY entrypoint.sh /usr/local/bin/

RUN set -eux; \
    \
    chmod a+x /usr/local/bin/clash; \
    chmod a+x /usr/local/bin/entrypoint.sh; \
    apk add --no-cache libcap; \
    # dumped by `pscap` of package `libcap-ng-utils`
    setcap cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap=eip /usr/local/bin/clash; \
    runDeps=' \
        iptables \
        ip6tables \
        ipset \
        iproute2 \
        curl \
        bind-tools \
    '; \
    apk add --no-cache \
        $runDeps \
        bash \
        bash-doc \
        bash-completion \
    ; \
    \
    rm -rf /var/cache/apk/*

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories

WORKDIR /clash_config

ENTRYPOINT ["entrypoint.sh"]
CMD ["su", "-s", "/bin/bash", "-c", "/usr/local/bin/clash -d /clash_config", "nobody"]
