# Key-Value store

## Prepare

- Install https://github.com/tarantool/http

## Run

    ./server.lua

## Authorization

With header

    Authorization: Bearer %token%

There is predefined `testtoken` token. Tokens are managed with `tarantoolctl` at `box.space.auth`.
