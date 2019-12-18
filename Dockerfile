# STAGE0
FROM dxdx/docker-builder-php:7.3 as builder
ARG DOCKER_IMAGE_VERSION=0.0.0
ARG SSH_PRIVATE_KEY
ARG BUILD_DEBUG=0

# Prepare ssh for composer
RUN if [ "${BUILD_DEBUG}" = "1" ]; then env ; fi
RUN if [ "${SSH_PRIVATE_KEY}" = "" ]; then echo "SSH_PRIVATE_KEY build-arg is required" && exit 1 ; fi
#RUN apt-get update && apt-get install -y unzip ssh git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /root/.ssh
RUN ssht sshkey --private-file=/root/.ssh/id_rsa --overwrite
RUN chmod 600 /root/.ssh/id_rsa
RUN if [ `grep -c ENCRYPTED /root/.ssh/id_rsa` = 1 ]; then echo "The SSH key cannot have password" && exit 1 ; fi
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts
RUN if [ "${BUILD_DEBUG}" = "1" ]; then cat /root/.ssh/id_rsa ; fi

# Composer
COPY src/. /app/
WORKDIR /app
RUN php --version
RUN composer --version
RUN if [ ! -e ".env" ]; then cp .env.example .env ; fi
RUN if [ ! -e "composer.lock" ]; then composer update ; fi
RUN composer install
RUN if [ -e ".env" ]; then rm .env ; fi
ADD docker/scripts/entrypoint.sh  ./
RUN chmod +x entrypoint.sh
RUN sed -i -s "s/0.0.0/${DOCKER_IMAGE_VERSION}/gi" .env.example
RUN echo "${DOCKER_IMAGE_VERSION}" > version.txt

# STAGE1
FROM bitnami/php-fpm:7.3.11-debian-9-r20-prod
ARG PLATFORM=linux
COPY --from=builder /usr/bin/fwatchdog /usr/bin/fwatchdog
COPY --from=builder /usr/bin/of-watchdog-wrapper /usr/bin/of-watchdog-wrapper
COPY --from=builder /usr/bin/ssht /usr/bin/ssht
COPY --from=builder /sbin/tini /sbin/tini
COPY --from=builder /usr/bin/composer /usr/bin/composer
COPY --from=builder /app /app
RUN apt-get update && apt-get install -y unzip ssh git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN rm -rf storage && mkdir -p storage storage/app/public storage/framework storage/cache storage/framework/sessions storage/framework/cache storage/framework/views storage/logs /var/www/.composer /var/www/.ssh && chown www-data.www-data -R /app /var/www && cd /app/storage
# RUN echo no | pecl install swoole
USER www-data
CMD [ "/app/entrypoint.sh", "php", "artisan", "serve", "--host=0.0.0.0", "--port=8080" ]
EXPOSE 8080