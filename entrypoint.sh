#!/bin/bash

prefix=${ENTRYPOINT_PREFIX:=DOTENV_}

env | grep "^$prefix" | sed "s/^$prefix//gi;" > .env

c=$(wc -l .env | cut -f1 -d" ")
if [ $c == 0 ]; then
    cp .env.example .env
    php artisan key:generate
fi

if [ "$ENTRYPOINT_DEBUG" ]; then
    echo "prefix: $prefix"
    echo
    env
    echo    
    echo ".env"
    cat .env
    echo
fi

eval $*
