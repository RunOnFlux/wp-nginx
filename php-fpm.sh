#!/bin/bash
pidfile="/usr/local/bin/php-fpm-pid"
# Start the process
php-fpm --allow-to-run-as-root -g $pidfile &
# Wait for 5 seconds
##sleep 5
# Kill the process
##pid=$(cat $pidfile)
#kill $pid
##sleep 5
# loop that resests php-fpm and folder permissions each 30 minutes
##while true; do

    # Start the process
    #php-fpm -g $pidfile &
    # reset wp folder permissions only if needed

    # Find and fix ownership only for files/directories not owned by www-data
##    ownership_changed=$(find /var/www/html/ \( \! -user www-data -o \! -group www-data \) -print0 2>/dev/null | \
##        xargs -0 -r chown www-data:www-data 2>/dev/null && echo "yes" || echo "no")

    # Find and fix permissions only for directories without group rwx permissions
##    dir_perms_changed=$(find /var/www/html/ -type d \! -perm -g=rwx -print0 2>/dev/null | \
##        xargs -0 -r chmod g+rwx 2>/dev/null && echo "yes" || echo "no")

    # Find and fix permissions only for files without group rw permissions
##    file_perms_changed=$(find /var/www/html/ -type f \! -perm -g=rw -print0 2>/dev/null | \
##        xargs -0 -r chmod g+rw 2>/dev/null && echo "yes" || echo "no")

    # Only log if changes were made
##    if [ "$ownership_changed" = "yes" ] || [ "$dir_perms_changed" = "yes" ] || [ "$file_perms_changed" = "yes" ]; then
##       echo "$(date '+%Y-%m-%d %H:%M:%S') - Permissions/ownership updated."
##    else
##        echo "$(date '+%Y-%m-%d %H:%M:%S') - No permission changes needed."
##    fi
    # Wait for 5 minutes
##    sleep 300
    # Kill the process
    #pid=$(cat $pidfile)
    #kill $pid
##done