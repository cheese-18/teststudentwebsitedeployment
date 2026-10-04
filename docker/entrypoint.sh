#!/bin/sh
set -e

# Clear stale caches
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true
php artisan package:discover --ansi || true

# Wait for PostgreSQL database to be reachable
if [ -n "$DB_HOST" ]; then
    echo "Checking database connection to $DB_HOST:$DB_PORT..."
    for i in $(seq 1 30); do
        nc -z -w 2 "$DB_HOST" "${DB_PORT:-5432}" && break || true
        echo "Waiting for database to become available ($i/30)..."
        sleep 2
    done
fi

# Run database migrations
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    php artisan migrate --force || echo "Migration command failed, continuing startup..."
fi

# Start PHP-FPM in the background
php-fpm -D

# Start Nginx in the foreground
exec nginx -g "daemon off;"
