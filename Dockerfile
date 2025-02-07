FROM php:8-fpm-alpine3.20

RUN apk upgrade --update && apk add --no-cache \
    bash \
    freetype-dev \ 
    libjpeg-turbo-dev \
    libpng-dev \
    php83-ctype \
    php83-openssl \
    mysql-client \
    mariadb-connector-c \ 
    && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql \
    && rm -f /usr/src/php.tar.xz /usr/src/php.tar.xz.asc 

WORKDIR /speedtest

COPY . .

# Prepare environment variabiles defaults

ARG TITLE=LibreSpeed
ENV TITLE=$TITLE
ARG MODE=standalone
ENV MODE=$MODE
ARG PASSWORD=password
ENV PASSWORD=$ARG
ARG TELEMETRY=false
ENV TELEMETRY=$TELEMETRY
ARG ENABLE_ID_OBFUSCATION=false
ENV ENABLE_ID_OBFUSCATION=$ENABLE_ID_OBFUSCATION
ARG REDACT_IP_ADDRESSES=false
ENV REDACT_IP_ADDRESSES=$REDACT_IP_ADDRESSES

EXPOSE 9000

CMD ["/bin/bash", "docker/entrypoint.sh"]