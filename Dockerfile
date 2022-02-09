# Building stage
FROM alpine:3 AS builder

ENV LOG4SHIB_VERSION=2.0.1
ENV SHIBBOLETH_SP_VERSION=3.3.0
ENV XERCES_C_VERSION=3.2.3
ENV XML_SECURITY_C=2.0.4
ENV CPP_OPENSAML_VERSION=3.2.1

RUN apk add --no-cache boost-dev zlib openssl openssl-dev libcurl gcc g++ make zlib-dev xmlsec curl-dev fcgi-dev
WORKDIR /tmp
RUN wget https://shibboleth.net/downloads/log4shib/$LOG4SHIB_VERSION/log4shib-$LOG4SHIB_VERSION.tar.gz -O - | tar xz  && \
    wget https://shibboleth.net/downloads/service-provider/$SHIBBOLETH_SP_VERSION/shibboleth-sp-$SHIBBOLETH_SP_VERSION.tar.gz -O - | tar xz && \
    wget http://apache.cs.utah.edu/xerces/c/3/sources/xerces-c-$XERCES_C_VERSION.tar.gz -O - | tar xz && \
    wget http://apache.osuosl.org/santuario/c-library/xml-security-c-$XML_SECURITY_C.tar.gz -O - | tar xz && \
    wget http://shibboleth.net/downloads/c++-opensaml/$CPP_OPENSAML_VERSION/xmltooling-$CPP_OPENSAML_VERSION.tar.gz -O - | tar xz && \
    wget http://shibboleth.net/downloads/c++-opensaml/$CPP_OPENSAML_VERSION/opensaml-$CPP_OPENSAML_VERSION.tar.gz  -O - | tar xz && \
    cd /tmp/log4shib-$LOG4SHIB_VERSION && \
    ./configure --prefix=/opt/shibboleth-sp && make install && \
    cd /tmp/xerces-c-$XERCES_C_VERSION && \
    ./configure --prefix=/opt/shibboleth-sp && make install && \
    cd /tmp/xml-security-c-$XML_SECURITY_C && \
    export PKG_CONFIG_PATH=/opt/shibboleth-sp/lib/pkgconfig:$PKG_CONFIG_PATH && \
    ./configure --without-xalan --disable-static --with-xerces=/opt/shibboleth-sp \
    --prefix=/opt/shibboleth-sp  && make install && \
    cd /tmp/xmltooling-$CPP_OPENSAML_VERSION && \
    ./configure --with-xmlsec=/opt/shibboleth-sp --prefix=/opt/shibboleth-sp -C && make install  && \
    cd /tmp/opensaml-$CPP_OPENSAML_VERSION && \
    ./configure --with-log4shib=/opt/shibboleth-sp --prefix=/opt/shibboleth-sp  -C && make install && \
    cd /tmp/shibboleth-sp-$SHIBBOLETH_SP_VERSION && \
    ./configure --prefix=/opt/shibboleth-sp --with-fastcgi && make install

ENV NGINX_VERSION nginx-1.20.0

RUN apk --update add pcre-dev build-base && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget https://github.com/openresty/headers-more-nginx-module/archive/master.zip -O nginx-headers-more.zip && \
    unzip nginx-headers-more.zip && \
    wget https://github.com/nginx-shib/nginx-http-shibboleth/archive/master.zip -O nginx-shib.zip && \
    unzip nginx-shib.zip && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    ./configure \
        --with-debug \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --add-module=/tmp/src/headers-more-nginx-module-master \
        --add-module=/tmp/src/nginx-http-shibboleth-master \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx && \
    make && \
    make install

# Production stage
FROM alpine:3

# Install latest Python3, PIP, Supervisord and libraries
RUN apk update && apk add --no-cache zlib py3-pip zlib openssl libcurl xmlsec fcgi-dev icu pcre && \
    pip install supervisor

COPY entrypoint.sh /entrypoint.sh

# Add users to drop privileges
RUN addgroup -S _shibd && adduser -S -H _shibd -G _shibd && \
    adduser -S -H nginx -G _shibd && \
    chmod +x /entrypoint.sh && \
    mkdir -p /var/log/nginx/

# Copy build outputs
COPY --from=builder /opt/shibboleth-sp/ /opt/shibboleth-sp/
COPY --from=builder /etc/nginx/conf/ /etc/nginx/
COPY --from=builder /usr/local/sbin/nginx /usr/local/sbin/nginx

# Copy config files
COPY supervisord.conf /etc/supervisord.conf
COPY nginx/ /etc/nginx/
COPY nginx-default.example.conf /etc/nginx/conf.d/default.conf
COPY shibd.logger /opt/shibboleth-sp/etc/shibboleth/

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
