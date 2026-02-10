#!/usr/bin/env bash

set -e

ssh app@buzzy-lb-101.df-iad-int.37signals.com \
  docker exec buzzy-load-balancer kamal-proxy rm buzzy-admin

ssh app@buzzy-lb-01.sc-chi-int.37signals.com \
  docker exec buzzy-load-balancer kamal-proxy rm buzzy-admin

ssh app@buzzy-lb-401.df-ams-int.37signals.com \
  docker exec buzzy-load-balancer kamal-proxy rm buzzy-admin
