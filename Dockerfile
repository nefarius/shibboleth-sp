# Building stage
FROM alpine:3 AS builder

ENV LOG4SHIB_VERSION=2.0.1
ENV $SHIBBOLETH_SP_VERSION=3.3.0
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

ENV NGINX_VERSION nginx-1.17.4

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

ENV PYTHON_VERSION=2.7.12-r0
ENV PY_PIP_VERSION=8.1.2-r0
ENV SUPERVISOR_VERSION=3.3.1

RUN apk update && apk add -u python=$PYTHON_VERSION py-pip=$PY_PIP_VERSION
RUN pip install supervisor==$SUPERVISOR_VERSION

# Allow Nginx to access Shibboleth sockets
#RUN adduser nginx _shibd

# Copy config files
COPY nginx-default.conf /etc/nginx/conf.d/default.conf
COPY supervisord.conf /etc/supervisor/
COPY nginx/ /etc/nginx/
COPY shibd.logger /opt/shibboleth-sp/etc/shibboleth/

EXPOSE 80

ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
