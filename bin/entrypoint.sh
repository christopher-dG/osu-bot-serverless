#!/usr/bin/env bash

if [[ $1 = 'bash' ]]; then
    exec bash
elif [[ $1 = 'julia' ]]; then
    exec julia
else
    exec $APP/bin/bot.jl "$@"
fi
