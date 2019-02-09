FROM php:5.6-cli as intermediate

MAINTAINER  LucaSpera "luca@docspera.com"

# Install deps
RUN apt-get -y update && apt-get -y install git zip unzip

# Install composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add credentials on build
ARG SSH_PRIVATE_KEY
RUN mkdir /root/.ssh/
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN  echo "    IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config

WORKDIR /code/

# Copy dependencies
COPY ./composer.json /code/composer.json
COPY ./composer.lock /code/composer.lock
RUN composer --no-interaction --ansi install

FROM php:5.6-apache
LABEL maintainer="Rion Dooley <dooley@tacc.utexas.edu>"

ENV APACHE_DOCROOT "/var/www"

# Add php extensions
RUN docker-php-ext-install mbstring
RUN a2enmod rewrite

# Add custom default apache virutal host with combined error and access
# logging to stdout
ADD docker/apache_vhost  /etc/apache2/sites-available/000-default.conf
ADD docker/php.ini /usr/local/etc/php

# Add custom entrypoint to inject runtime environment variables into
# beanstalk console config
ADD docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint
CMD ["/usr/local/bin/docker-entrypoint"]

# Add project from current repo to enable automated build
WORKDIR "${APACHE_DOCROOT}"
COPY --from=0 /code/vendor/ ./vendor
ADD . ./
