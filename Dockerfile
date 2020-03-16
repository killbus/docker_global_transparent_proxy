FROM golang:alpine as builder

RUN apk add --no-cache make git curl

WORKDIR /go
RUN set -eux; \
    \
    curl -L -O https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb; \
    git clone https://github.com/Kr328/clash.git /clash-src

WORKDIR /clash-src

RUN go mod download

COPY Makefile /clash-src/Makefile
RUN make current

FROM alpine:latest

# RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.11/main/" > /etc/apk/repositories

COPY --from=builder /clash-src/bin/clash /usr/local/bin/

COPY entrypoint.sh /usr/local/bin/

RUN set -eux; \
    \
    apk add --no-cache libcap; \
    setcap cap_net_raw,cap_net_admin=eip /usr/local/bin/clash; \
    runDeps=' \
        iptables \
        ip6tables \
        ipset \
        iproute2 \
    '; \
    apk add --no-cache \
        $runDeps \
        bash \
        bash-doc \
        bash-completion \
    ; \
    \
    rm -rf /var/cache/apk/*; \
    chmod a+x /usr/local/bin/entrypoint.sh

COPY --from=builder /go/Country.mmdb /root/.config/clash/
COPY config.yaml /root/.config/clash/

WORKDIR /clash_config

ENTRYPOINT ["entrypoint.sh"]
CMD ["su", "-s", "/bin/bash", "-c", "/usr/local/bin/clash -d /clash_config", "nobody"]