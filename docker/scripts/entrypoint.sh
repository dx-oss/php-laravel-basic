#!/bin/bash

function run {
    echo "$*"
    eval $*
}

prefix=${ENTRYPOINT_PREFIX:=DOTENV_}

env | grep "^$prefix" | sed "s/^$prefix//gi;" > .env

c=$(wc -l .env | cut -f1 -d" ")
if [ $c == 0 ]; then
    run cp .env.example .env
    run php artisan key:generate
fi

if [ "$ENTRYPOINT_DEBUG" ]; then
    echo "prefix: $prefix"
    run env
    run cat .env
else
    run php artisan route:clear
    run php artisan route:cache
    run php artisan config:clear
    run php artisan config:cache
fi

run $*
