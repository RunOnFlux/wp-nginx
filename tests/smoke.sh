#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: bash tests/smoke.sh IMAGE}"
container="$(docker run -d --network none --add-host fluxnode.service:127.0.0.1 "$image")"
cleanup() {
    result=$?
    if [ "$result" -ne 0 ]; then docker logs "$container" >&2; fi
    docker rm -fv "$container" >/dev/null
    exit "$result"
}
trap cleanup EXIT

# Exercise the real entrypoint and CMD, allowing for the cluster lookup retries.
ready=false
for attempt in {1..60}; do
    if docker exec "$container" curl -s --max-time 1 -o /dev/null http://127.0.0.1/nginx.conf; then
        ready=true
        break
    fi
    sleep 1
done
test "$ready" = true

docker exec -i "$container" sh -s <<'CHECKS'
set -eu
test "$(nginx -v 2>&1)" = 'nginx version: nginx/1.30.7'
nginx -t -c /var/www/html/nginx.conf
php-fpm -t
printf 'static-ok' > /var/www/html/smoke.txt
printf '%s' '<?php header("Content-Type: text/plain"); echo "php-ok"; ?>' > /var/www/html/smoke.php
test "$(curl -fsS --max-time 10 http://127.0.0.1/smoke.txt)" = static-ok
test "$(curl -fsS --max-time 10 http://127.0.0.1/smoke.php)" = php-ok
for path in nginx.conf xmlrpc.php .htaccess; do
    test "$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' "http://127.0.0.1/$path")" = 403
done
curl -fsSI --max-time 10 http://127.0.0.1/smoke.txt | grep -qi 'X-Content-Type-Options: nosniff'
echo 'PASS: NGINX version, configuration, startup, static HTTP, PHP-FPM, and access restrictions'
CHECKS
