FROM php:7.4-apache

USER www-data
RUN chown -R www-data:www-data /var/www/ && chmod -R 755 /var/www

# Setup Debian
RUN apt-get upgrade && apt-get update && ACCEPT_EULA=Y && apt-get -y install --no-install-recommends \
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libzip-dev \
        libgeoip-dev \
        libxml2-dev \
        libxslt-dev \
        libtidy-dev \
        libssl-dev \
        zlib1g-dev \
        libpng-dev \
        libwebp-dev \
        libgmp-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libaio1 \
        libldap2-dev \
        apt-file \
        wget \
        vim \
        gnupg \
        gnupg2 \
        zip \
        git \
        gcc \
        g++ \
        autoconf \
        libc-dev \
        pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
RUN pecl install redis \
    && pecl install geoip-1.1.1 \
    && pecl install apcu \
    && pecl install memcached \
    && pecl install timezonedb \
    && pecl install grpc \
    && docker-php-ext-enable redis geoip apcu memcached timezonedb grpc 

# RUN apt-get update && apt-get install -y libc-client-dev libkrb5-dev && rm -r /var/lib/apt/lists/*
# RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
#    && docker-php-ext-install imap \
#    && docker-php-ext-configure zip \
#    && docker-php-ext-configure gd --with-freetype --with-jpeg \
#    && apt-get clean

# RUN docker-php-ext-install gd calendar gmp ldap sysvmsg pcntl iconv bcmath xml mbstring pdo tidy gettext imap intl pdo_mysql mysqli simplexml xmlrpc xsl xmlwriter zip opcache exif sockets \
#    && printf "log_errors = On \nerror_log = /dev/stderr\n" > /usr/local/etc/php/conf.d/php-logs.ini

# Apache settings
COPY etc/apache2/conf-enabled/host.conf /etc/apache2/conf-enabled/host.conf
COPY etc/apache2/apache2.conf /etc/apache2/apache2.conf
COPY etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf

RUN service apache2 restart

# PHP settings
COPY etc/php/production.ini /usr/local/etc/php/conf.d/production.ini

# Composer
RUN mkdir -p /usr/local/ssh
COPY etc/ssh/* /usr/local/ssh/
RUN pwd
RUN chmod -R 777 /usr/local/ssh/install-composer.sh
RUN /usr/local/ssh/install-composer.sh && \
    mv composer.phar /usr/local/bin/composer && \
#    a2enmod proxy && \
#    a2enmod proxy_http && \
#    a2enmod proxy_ajp && \
#    a2enmod rewrite && \
#    a2enmod deflate && \
#    a2enmod headers && \
#    a2enmod proxy_balancer && \
#    a2enmod proxy_connect && \
#    a2enmod ssl && \
#    a2enmod cache && \
#    a2enmod expires && \
# Run apache on port 8080 instead of 80 due. On linux, ports under 1024 require admin privileges and we run apache as www-data.
    sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf && \
    chmod g+w /var/log/apache2 && \
    chmod 777 /var/lock/apache2 && \
    chmod 777 /var/run/apache2 && \
    echo "<?php echo phpinfo(); ?>" > /var/www/html/phpinfo.php
# RUN sudo semanage port -a -t http_port_t -p tcp 443 80 8080 8443

RUN if which apache2 > /dev/null 2>&1; then \
        sed -i -e 's#^export \([^=]\+\)=\(.*\)$#export \1=${\1:=\2}#' /etc/apache2/envvars \
        # Apache - Enable mod rewrite and headers
        && a2enmod headers rewrite \
        # Apache - Disable useless configuration
        && a2disconf serve-cgi-bin \
        # Apache - remoteip module
        && a2enmod remoteip \
        && sed -i 's/%h/%a/g' /etc/apache2/apache2.conf \
        && a2enconf remoteip \
        # Apache - Hide version
        && sed -i 's/^ServerTokens OS$/ServerTokens Prod/g' /etc/apache2/conf-available/security.conf \
        && a2enconf servername \
        # Apache - Logging
        && sed -i -e 's/vhost_combined/combined/g' -e 's/other_vhosts_access/access/g' /etc/apache2/conf-available/other-vhosts-access-log.conf \
        # Apache- Prepare to be run as non root user
        && mkdir -p /var/lock/apache2 /var/run/apache2 \
        && chgrp -R 0 /var/lock/apache2 /var/log/apache2 /var/run/apache2 \
        && chmod -R g=u /var/lock/apache2 /var/log/apache2 /var/run/apache2 \
        && rm -f /var/log/apache2/*.log \
        && ln -s /proc/self/fd/2 /var/log/apache2/error.log \
        && ln -s /proc/self/fd/1 /var/log/apache2/access.log \
        && sed -i -e 's/80/8080/g' -e 's/443/8443/g' /etc/apache2/ports.conf; \
    fi

COPY var/www/html/index.php /var/www/html/index.php

RUN echo ${APACHE_PID_FILE}
RUN echo ${APACHE_RUN_USER}
RUN echo ${APACHE_RUN_GROUP}

RUN chmod -R 777 /etc/apache2/envvars

EXPOSE 8080 8443 443 80

## Add script to deal with Docker Secrets before starting apache
COPY secrets.sh /usr/local/bin/secrets
COPY startup.sh /usr/local/bin/startup
RUN chmod 755 /usr/local/bin/secrets && chmod 755 /usr/local/bin/startup

### PROD ENVIRONMENT SPECIFIC ###
################################

ENV PROVISION_CONTEXT "production"

################################
CMD ["startup"]
 
