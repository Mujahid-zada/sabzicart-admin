#!/bin/bash
# deploy-laravel.sh - deploy the SabziCart admin panel (Laravel) to a server
# Usage: deploy-laravel.sh USER@SERVER
#   local deploy:  deploy-laravel.sh zaadan@localhost
#   AWS deploy:    deploy-laravel.sh ubuntu@admin.sabzicart.local

# Variables in the ssh commands are filled in on OUR machine, as we want:
# shellcheck disable=SC2029

src="./"
dest="/var/www/sabzicart-admin"
site="admin.sabzicart.local"
artisan="sudo -u www-data php $dest/artisan"
composer="composer install --no-dev --optimize-autoloader --no-interaction"

fail() { echo "==> FAILED: $1"; exit 1; }

if [ $# -ne 1 ]; then
    echo "Usage: $0 USER@SERVER"
    exit 1
fi
server="$1"
host="${server#*@}"

[ -f "${src}artisan" ] || fail "${src}artisan not found. Is this a Laravel project?"

# Detect PHP-FPM service on the target (php8.3-fpm, php8.5-fpm, ...)
php_fpm="$(ssh "$server" "php -r 'echo \"php\".PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION.\"-fpm\";'" 2>/dev/null)"
[ -n "$php_fpm" ] || fail "could not detect PHP-FPM service on $server"

echo "==> 1/5 Copying code to $server:$dest"
rsync -avz --delete \
    --exclude /.env \
    --exclude /vendor/ \
    --exclude /node_modules/ \
    --exclude /storage/ \
    --exclude /bootstrap/cache/ \
    --exclude /database/database.sqlite \
    "$src" "$server:$dest/" || fail "could not copy the files"

echo "==> 2/5 Installing PHP packages on the server"
ssh "$server" "cd $dest && $composer" || fail "composer install failed"

echo "==> 3/5 Updating the database"
ssh "$server" "$artisan migrate --force" || fail "migrations failed"

echo "==> 4/5 Caching config, routes and views (reloading $php_fpm)"
ssh "$server" "$artisan optimize && sudo systemctl reload $php_fpm" || fail "could not optimize or reload PHP"

echo "==> 5/5 Checking http://$site/health"
url="http://$host/health"
code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $site" "$url")
[ "$code" = "200" ] || fail "the app answered HTTP $code"

echo "==> SUCCESS: the admin panel is live"
curl -s -H "Host: $site" "http://$host/health"
echo
