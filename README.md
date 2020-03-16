# docker_global_transparent_proxy
使用clash +docker 进行路由转发实现全局透明代理

## 食用方法
1. 开启混杂模式

    `ip link set eth0 promisc on`

1. docker创建网络,注意将网段改为你自己的

    `docker network create -d macvlan --subnet=192.168.1.0/24 --gateway=192.168.1.1 -o parent=eth0 macnet`

1. 提前准备好正确的clash config , 必须打开redir在7892, 以及dns在53端口

1. 运行容器

    `sudo docker run --name clash_tp -d -v /your/path/clash_config:/clash_config  --network macnet --ip 192.168.1.100 --privileged zhangyi2018/clash_transparent_proxy`

1. 将手机/电脑等客户端 网关设置为容器ip,如192.168.1.100 ,dns也设置成这个


## 附注 : 

1. 只要规则设置的对, 支持国内直连,国外走代理
1. 只在linux 测试过,win没试过, mac是不行, 第二步创建网络不行, docker自己的问题, 说不定以后哪天docker for mac支持了?

## 构建方法
`docker buildx build --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64/v8 -t zhangyi2018/clash_transparent_proxy:1.0.7 -t zhangyi2018/clash_transparent_proxy:latest . --push`

## clash 配置参考

### TUN 模式

docker-compose.yml

```
version: "3.4"

services:
  clash_tp:
    container_name: clash_tp
    image: fy1128/clash_transparent_proxy:arm64v8
    privileged: true
    logging:
      options:
        max-size: '10m'
        max-file: '3'
    restart: unless-stopped
    volumes:
      - /root/docker/clash_tp/clash_config:/clash_config
    environment:
      - TZ=Asia/Shanghai
      - EN_MODE_TUN=1
      - EN_MODE=redir-host
    networks:
      dMACvLAN:
        ipv4_address: 192.168.5.254
      aio:
    dns:
      - 114.114.114.114
```

clash config.yaml

```
# port of HTTP
port: 7890

# port of SOCKS5
socks-port: 7891

# redir port for Linux and macOS
# 必须打开
redir-port: 7892

allow-lan: true

# Only applicable when setting allow-lan to true
# "*": bind all IP addresses
# 192.168.122.11: bind a single IPv4 address
# "[aaaa::a8aa:ff:fe09:57d8]": bind a single IPv6 address
bind-address: "*"

# Rule / Global/ Direct (default is Rule)
mode: Rule

# set log level to stdout (default is info)
# info / warning / error / debug / silent
log-level: debug

# RESTful API for clash
external-controller: 0.0.0.0:9090

# you can put the static web resource (such as clash-dashboard) to a directory, and clash would serve in `${API}/ui`
# input is a relative path to the configuration directory or an absolute path
external-ui: dashboard

# Secret for RESTful API (Optional)
# secret: ""

# experimental feature
experimental:
  ignore-resolve-fail: true # ignore dns resolve fail, default value is true

# authentication of local SOCKS5/HTTP(S) server
# authentication:
#  - "user1:pass1"
#  - "user2:pass2"

# # experimental hosts, support wildcard (e.g. *.clash.dev Even *.foo.*.example.com)
# # static domain has a higher priority than wildcard domain (foo.example.com > *.example.com)
hosts:
   '*.clash.dev': 127.0.0.1
   'alpha.clash.dev': '::1'
   'trojan': 172.28.0.233

tun:
  enable: true
  device-url: dev://clash0 #specific a TUN device
  dns-listen: 0.0.0.0:1053 #TUN dns listen port, only DNS requires bypassed it, tun can hijack them
dns:
  #必须打开dns,防止污染
  enable: true # set true to enable dns (default is false)
  ipv6: false # default is false
  listen: 0.0.0.0:1053
  enhanced-mode: redir-host # redir-host or fake-ip
  # fake-ip-range: 198.18.0.1/16 # if you don't know what it is, don't change it
  #fake-ip-filter: # fake ip white domain list
  #  - "*.lan"
  #  - localhost.ptlogin2.qq.com
  nameserver:
    # use my privileged overture container as DNS provider
    - 192.168.5.252
  #  - 114.114.114.114
  #  - tls://dns.rubyfish.cn:853 # dns over tls
  #  - https://1.1.1.1/dns-query # dns over https
  #fallback: # concurrent request with nameserver, fallback used when GEOIP country isn't CN
  #  - tls://dns.rubyfish.cn:853
  #  - tls://1.0.0.1:853
  #  - tls://dns.google:853
  #fallback-filter:
  #  geoip: true # default
  #  ipcidr: # ips in these subnets will be considered polluted
  #    - 240.0.0.0/4
Proxy:
  - name: a-trojan-proxy
    type: socks5
    server: trojan
    port: "1080"

...
```

**参考资料**

配置文件

[https://lancellc.gitbook.io/clash/whats-new/clash-tun-mode/clash-tun-mode-2/setup-for-redir-host-mode](https://lancellc.gitbook.io/clash/whats-new/clash-tun-mode/clash-tun-mode-2/setup-for-redir-host-mode)


路由及防火墙设置

[kr328-clash-setup-scripts](https://github.com/h0cheung/kr328-clash-setup-scripts)

overturn DNS
[overturn + clash in docker as dns server and transparent proxy gateway](https://gist.github.com/killbus/69fdabdd1d8ae8f4030f4f96307ffa1b)