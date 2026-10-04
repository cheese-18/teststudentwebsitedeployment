#!/bin/sh
set -e

# Cache configuration & routes
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

# Run database migrations
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running migrations..."
    php artisan migrate --force
fi

# Start PHP-FPM in the background
php-fpm -D

# Start Nginx in the foreground
exec nginx -g "daemon off;"
