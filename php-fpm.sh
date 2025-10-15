#!/bin/bash
pidfile="/usr/local/bin/php-fpm-pid"
# Start the process
php-fpm -g $pidfile &
# Wait for 5 seconds
sleep 5
# Kill the process
pid=$(cat $pidfile)
#kill $pid
sleep 5
# loop that resests php-fpm and folder permissions each 30 minutes
#while true; do

    # Start the process
    #php-fpm -g $pidfile &
    # reset wp folder permissions
 #   chmod -R g+rwx /var/www/html/
 #   chown -R www-data:www-data /var/www/html/
 #   echo "Reseted Permissions."
    # Wait for 5 minutes
 #   sleep 300
    # Kill the process
    #pid=$(cat $pidfile)
    #kill $pid
#done