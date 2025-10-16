#!/bin/bash
pidfile="/usr/local/bin/php-fpm-pid"
nginx_pidfile="/var/run/nginx.pid"

# Function to start PHP-FPM
start_php_fpm() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting PHP-FPM..."
    php-fpm --allow-to-run-as-root -g $pidfile &
    sleep 2  # Give it time to start
    if pgrep -f "php-fpm: master process" > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - PHP-FPM started successfully."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: PHP-FPM failed to start!"
    fi
}

# Function to check if PHP-FPM is running
check_php_fpm() {
    # Check if php-fpm master process is running
    if pgrep -f "php-fpm: master process" > /dev/null; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Function to start Nginx
start_nginx() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Nginx..."
    nginx -g "daemon off;" -c "/var/www/html/nginx.conf" &
    sleep 2  # Give it time to start
    if pgrep -f "nginx: master process" > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Nginx started successfully."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Nginx failed to start!"
    fi
}

# Function to check if Nginx is running
check_nginx() {
    # Check if nginx master process is running
    if pgrep -f "nginx: master process" > /dev/null; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Initial start of PHP-FPM
start_php_fpm

# Note: Nginx should be started by the main CMD, but check if we need to start it
sleep 5  # Give main CMD time to start nginx
if ! check_nginx; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Nginx not detected, starting it..."
    start_nginx
fi

# Monitoring loop - check every 60 seconds
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting PHP-FPM and Nginx monitoring..."
while true; do
    sleep 60  # Check every minute

    # Check PHP-FPM
    if check_php_fpm; then
        # PHP-FPM is running - optionally log this
        # echo "$(date '+%Y-%m-%d %H:%M:%S') - PHP-FPM is running."
        :  # Do nothing, just continue
    else
        # PHP-FPM is not running - restart it
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: PHP-FPM is not running! Attempting to restart..."

        # Clean up any stale PID file
        if [ -f "$pidfile" ]; then
            rm -f "$pidfile"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Removed stale PHP-FPM PID file."
        fi

        # Try to kill any zombie PHP-FPM processes
        pkill -9 -f "php-fpm" 2>/dev/null

        # Restart PHP-FPM
        start_php_fpm
    fi

    # Check Nginx
    if check_nginx; then
        # Nginx is running - optionally log this
        # echo "$(date '+%Y-%m-%d %H:%M:%S') - Nginx is running."
        :  # Do nothing, just continue
    else
        # Nginx is not running - restart it
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Nginx is not running! Attempting to restart..."

        # Clean up any stale PID file
        if [ -f "$nginx_pidfile" ]; then
            rm -f "$nginx_pidfile"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Removed stale Nginx PID file."
        fi

        # Try to kill any zombie nginx processes
        pkill -9 -f "nginx" 2>/dev/null

        # Restart Nginx
        start_nginx
    fi
done