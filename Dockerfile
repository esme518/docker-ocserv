#
# Dockerfile for ocserv
#

FROM alpine:3.11

ARG OC_VERSION="1.1.2"

RUN buildDeps=" \
		g++ \
		gnutls-dev \
		gpgme \
		libev-dev \
		libnl3-dev \
		libseccomp-dev \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		readline-dev \
		tar \
		xz \
	"; \
	set -x \
	&& apk add --update --virtual .build-deps $buildDeps \
	&& apk add curl gnutls-utils iptables \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz.sig" -o ocserv.tar.xz.sig \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys 96865171 7F343FA7 \
	&& gpg --verify ocserv.tar.xz.sig \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cd / \
	&& rm -rf /usr/src/ocserv \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/local/sbin/ocserv \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| xargs -r apk info --installed \
			| sort -u \
		)" \
	&& apk add --virtual .run-deps $runDeps \
	&& apk del .build-deps \
	&& apk add libnl3 readline \
	&& rm -rf /var/cache/apk

WORKDIR /etc/ocserv

COPY ocserv.conf /etc/ocserv/ocserv.conf
COPY All /etc/ocserv/config-per-group/All
COPY docker-entrypoint.sh /entrypoint.sh

ENV PORT     443
ENV IPV4     10.10.10.0
ENV IPV4MASK 255.255.255.0
ENV DNS      1.1.1.1
ENV DNS2     1.0.0.1

EXPOSE $PORT/tcp
EXPOSE $PORT/udp

ENTRYPOINT ["/entrypoint.sh"]

CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
