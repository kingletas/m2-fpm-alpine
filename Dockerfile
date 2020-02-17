FROM php:7.1-fpm-alpine
# Register the COMPOSER_HOME environment variable
ENV COMPOSER_HOME /composer
# Add global binary directory to PATH and make sure to re-export it
ENV PATH /composer/vendor/bin:$PATH
ARG BUILD_DATE
ARG VCS_REF
# Allow Composer to be run as root
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN mkdir /composer
RUN set -ex \
    && apk update \
    && apk add --no-cache git rsync mysql-client tzdata curl shadow icu libpng freetype libjpeg-turbo postgresql-dev libffi-dev \
    && apk add --no-cache --virtual build-dependencies icu-dev libxml2-dev libmcrypt-dev  libxslt-dev freetype-dev libpng-dev libjpeg-turbo-dev g++ make autoconf \
    && docker-php-source extract \
    && pecl install xdebug redis \
    && docker-php-ext-enable xdebug redis  \
    && docker-php-source delete \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) sockets pdo pgsql pdo_mysql pdo_pgsql intl zip gd mcrypt xsl soap bcmath pcntl \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    # IONCUBE LOADER AND USER CHANGE
    && mkdir /ioncube \
    #&& usermod -u 1000 www-data \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
    &&  echo "memory_limit=-1" > $PHP_INI_DIR/conf.d/memory-limit.ini \
    &&  echo 'sendmail_path=/usr/sbin/sendmail -S mailhog:1025' > $PHP_INI_DIR/conf.d/sendmail.ini \
    && cp /usr/share/zoneinfo/CST6CDT /etc/localtime \
    && echo 'CET' > /etc/timezone \
    && export m="bin/magento" \
    && echo "zend_extension=/ioncube/ioncube_loader_lin_7.1.so" > $PHP_INI_DIR/conf.d/00-ioncube.ini \
    #n98
    && wget https://files.magerun.net/n98-magerun2.phar \
    && chmod +x ./n98-magerun2.phar \
    && mv ./n98-magerun2.phar /usr/local/bin/n98
COPY ioncube_loader_lin_7.1.so /ioncube/
COPY xdebug.ini /usr/local/etc/php/conf.d/xdebug-dev.ini
RUN apk add --update --no-cache nodejs nodejs-npm \
    && git clone https://github.com/magento/baler.git \
    && cd baler \
    && npm install \
    && npm audit fix \
    && npm run build \
    && npm link
RUN cd && git clone https://github.com/magento/magento-coding-standard.git \
    && cd magento-coding-standard \
    && composer install
RUN cd && wget https://phar.phpunit.de/phpcpd.phar && chmod +x phpcpd.phar && mv phpcpd.phar /usr/local/bin/phpcpd \
    && wget -c https://phpmd.org/static/latest/phpmd.phar && chmod +x phpmd.phar && mv phpmd.phar /usr/local/bin/phpmd
WORKDIR /app
