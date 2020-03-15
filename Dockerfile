FROM dreamacro/clash:latest

COPY entrypoint.sh /usr/local/bin/
COPY config.yaml /root/.config/clash/

RUN apk add --no-cache \
 bash \
 bash-doc \
 bash-completion  \
 iptables \
 ipset \
 iproute2 \
 rm -rf /var/cache/apk/* && \
 chmod a+x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["/clash"]