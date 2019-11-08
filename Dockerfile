#ARG DOCKER_IMAGE=php:7.1.33-fpm
ARG DOCKER_IMAGE=php:7.3.11-fpm

FROM composer:1.9 as composer
FROM dxcn/ssht:0.0.1 as ssht
FROM csakshaug/of-watchdog-wrapper:v0.0.2 as wrapper
FROM openfaas/of-watchdog:0.7.2 as watchdog

# STAGE0
FROM ${DOCKER_IMAGE} as builder
ARG DOCKER_IMAGE_VERSION=0.0.0
ARG SSH_PRIVATE_KEY
ARG BUILD_DEBUG=0
COPY --from=composer /usr/bin/composer /usr/bin/composer

# Prepare ssh for composer
COPY --from=ssht /usr/bin/ssht /usr/bin/ssht
RUN if [ "${BUILD_DEBUG}" = "1" ]; then env ; fi
#RUN if [ "${SSH_PRIVATE_KEY}" = "" ]; then echo "SSH_PRIVATE_KEY build-arg is required" && exit 1 ; fi
RUN apt-get update && apt-get install -y unzip ssh git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /root/.ssh
RUN ssht sshkey --private-file=/root/.ssh/id_rsa --overwrite
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa 
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
RUN curl -Lfs -o /sbin/tini https://github.com/krallin/tini/releases/download/v0.18.0/tini && chmod +x /sbin/tini

# STAGE1
FROM ${DOCKER_IMAGE}
ARG PLATFORM=linux
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
COPY --from=wrapper /usr/bin/of-watchdog-wrapper /usr/bin/of-watchdog-wrapper
COPY --from=builder /app /app
COPY --from=builder /sbin/tini /sbin/tini
COPY --from=composer /usr/bin/composer /usr/bin/composer
RUN apt-get update && apt-get install -y unzip ssh git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN rm -rf storage && mkdir -p storage storage/app/public storage/framework storage/cache storage/framework/sessions storage/framework/cache storage/framework/views storage/logs /var/www/.composer /var/www/.ssh && chown www-data.www-data -R /app /var/www && cd /app/storage
USER www-data
CMD [ "/sbin/tini", "/app/entrypoint.sh", "--", "php", "artisan", "serve", "--host=0.0.0.0", "--port=8080" ]
EXPOSE 8080
