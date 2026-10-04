#!/bin/sh
set -e

# Configure PHP-FPM pool settings
if [ -f /usr/local/etc/php-fpm.d/www.conf ]; then
    sed -i 's/pm.max_children = 5/pm.max_children = 20/g' /usr/local/etc/php-fpm.d/www.conf || true
fi

# Configure Nginx port from $PORT env variable (default 80, Render often uses 10000)
PORT="${PORT:-80}"
sed -i "s/listen 80;/listen ${PORT};/g" /etc/nginx/nginx.conf || true

# Ensure storage and bootstrap/cache permissions at container startup
mkdir -p /var/www/html/storage/logs \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/framework/cache \
         /var/www/html/bootstrap/cache

chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Generate APP_KEY if missing
if [ -z "$APP_KEY" ]; then
    php artisan key:generate --force || true
fi

# Link storage
php artisan storage:link || true

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

# Cache optimized configuration and routes
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Start PHP-FPM in the background
php-fpm -D

# Start Nginx in the foreground
exec nginx -g "daemon off;"
