#!/usr/bin/env bash

## use this script to easily register new
## users without having to enable registration
## on the matrix or MAS servers

docker compose exec mas mas-cli manage register-user
