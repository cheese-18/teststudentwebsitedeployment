FROM php:8.4-fpm-alpine

# Set environment for Composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install system dependencies & PHP extensions
RUN apk add --no-cache \
    nginx \
    nodejs \
    npm \
    git \
    curl \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    oniguruma-dev \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    mysql-client \
    postgresql-dev \
    postgresql-client \
    mariadb-connector-c-dev

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql pdo_pgsql mbstring exif pcntl bcmath gd zip

# Get Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer manifest first to leverage caching and debug dependencies
COPY composer.json composer.lock* /var/www/html/

# Install composer dependencies
RUN composer install --no-dev --no-interaction --no-scripts --optimize-autoloader --ignore-platform-reqs

# Copy application source code
COPY . /var/www/html

# Run composer dump-autoload without scripts
RUN composer dump-autoload --optimize --no-dev --no-scripts

# Install NPM dependencies & build frontend assets
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi && npm run build && rm -rf node_modules

# Create required directories for Nginx and PHP-FPM
RUN mkdir -p /run/nginx /var/log/nginx /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/log/nginx /var/lib/nginx \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Copy Nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
