FROM dreamacro/clash:latest

COPY entrypoint.sh /usr/local/bin/
COPY config.yaml /root/.config/clash/

RUN set -eux; \
    \
    runDeps=' \
        iptables \
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
    mv /clash /usr/local/bin/; \
    chmod a+x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/local/bin/clash","-d","/clash_config"]