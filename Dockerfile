FROM alpine:3.9 AS builder

LABEL maintainer="metowolf <i@i-meto.com>"

ARG HAPROXY_VERSION=1.9.6
ARG HAPROXY_VERSION_MOJOR=1.9
ARG HAPROXY_URL=http://www.haproxy.org/download/$HAPROXY_VERSION_MOJOR/src/haproxy-$HAPROXY_VERSION.tar.gz

RUN set -x \
  && apk update \
  && apk add \
    ca-certificates \
    gcc \
    libc-dev \
    linux-headers \
    lua5.3-dev \
    make \
    openssl \
    openssl-dev \
    pcre-dev \
    readline-dev \
    tar \
    zlib-dev \
  && wget ${HAPROXY_URL} \
  && wget ${HAPROXY_URL}.sha256 \
  && sha256sum -c haproxy-${HAPROXY_VERSION}.tar.gz.sha256 \
  && mkdir haproxy \
  && tar -xzf haproxy-${HAPROXY_VERSION}.tar.gz -C haproxy --strip-components=1 \
  && cd haproxy \
  && makeOpts=' \
      TARGET=linux2628 \
      USE_LUA=1 LUA_INC=/usr/include/lua5.3 LUA_LIB=/usr/lib/lua5.3 \
      USE_OPENSSL=1 \
      USE_PCRE=1 PCREDIR= \
      USE_ZLIB=1 \
    ' \
  && make -j "$(getconf _NPROCESSORS_ONLN)" all $makeOpts \
  && make install-bin $makeOpts \
  && mkdir -p /usr/local/etc/haproxy \
  && cp -R examples/errorfiles /usr/local/etc/haproxy/errors



FROM alpine:3.9

LABEL maintainer="metowolf <i@i-meto.com>"

COPY --from=builder /usr/local/ /usr/local/

RUN set -x \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/ \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
  && apk --no-cache add $runDeps

STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
