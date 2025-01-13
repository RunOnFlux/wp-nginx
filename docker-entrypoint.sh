#!/usr/bin/env bash

set -Eeuo pipefail

sourceTarArgs=(
  --create
  --file -
  --directory /usr/src/wordpress
  --owner "www-data" --group "www-data"
)
targetTarArgs=(
  --extract
  --file -
  --directory /var/www/html
)

#Remove akismet plugin
folder="/usr/src/wordpress/wp-content/plugins/akismet"
if [ -d "$folder" ]; then
  # Delete the folder and its contents
  rm -rf "$folder"
  echo "Folder deleted: $folder"
else
  echo "Folder does not exist: $folder"
fi
#Remove hello dolly plugin
file_path="/usr/src/wordpress/wp-content/plugins/hello.php"
if [ -f "$file_path" ]; then
    echo "Deleting $file_path..."
    rm "$file_path"
    echo "File deleted successfully."
else
    echo "File $file_path does not exist."
fi

#copy nginx config
file_path="/etc/nginx/nginx.conf"
dst_path="/var/www/html/nginx.conf"
if [ -f "$dst_path" ]; then
    echo "$dst_path already exist."
else
    echo "Creating $dst_path..."
    cp "$file_path" "/var/www/html/"
    echo "Nginx file copied successfully."
fi

# loop over "pluggable" content in the source, and if it already exists in the destination, skip it
# https://github.com/docker-library/wordpress/issues/506 ("wp-content" persisted, "akismet" updated, WordPress container restarted/recreated, "akismet" downgraded)
for contentPath in \
  /usr/src/wordpress/.htaccess \
  /usr/src/wordpress/wp-content/*/*/ \
; do
  contentPath="${contentPath%/}"
  [ -e "$contentPath" ] || continue
  contentPath="${contentPath#/usr/src/wordpress/}" # "wp-content/plugins/akismet", etc.
  if [ -e "$PWD/$contentPath" ]; then
    echo >&2 "WARNING: '$PWD/$contentPath' exists! (not copying the WordPress version)"
    sourceTarArgs+=( --exclude "./$contentPath" )
  fi
done
if [ -d "/var/www/html/wp-admin" ] && [ -f "/var/www/html/wp-config.php" ] && [ -f "/var/www/html/index.php" ]; then
    echo "Wordpress already there skipping..."
else
    tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
    echo >&2 "Complete! WordPress has been successfully copied to $PWD"
fi



# Add a new user for SFTP access with key-based authentication
USERNAME="sftpuser"
if id "$USERNAME" &>/dev/null; then
   echo "User $USERNAME already exists."
else
   useradd -m -d /home/sftpuser -s /sbin/nologin sftpuser
   mkdir /home/sftpuser/.ssh
fi
chmod 700 /home/sftpuser/.ssh


# Add the public key to the authorized keys file
if [ -v PUBLIC_KEY ]; then
    echo "ssh-rsa $PUBLIC_KEY" > /home/sftpuser/.ssh/authorized_keys
    chown -R sftpuser:sftpuser /home/sftpuser/.ssh
    chmod 600 /home/sftpuser/.ssh/authorized_keys

    echo "ssh-rsa $PUBLIC_KEY" > /home/sshuser/.ssh/authorized_keys
    chown sshuser:sshgroup /home/sshuser/.ssh/authorized_keys
    chmod 600 /home/sshuser/.ssh/authorized_keys

    echo "Public key is: $PUBLIC_KEY"

    usermod -aG www-data sftpuser 
    usermod -aG www-data sshuser 
    

    chmod -R g+rwx /var/www/html/
    chown -R www-data:www-data /var/www/html/
    
else
    echo "PUBLIC_KEY is not defined."
fi

# Start background processes
/usr/local/php-fpm.sh &
nginx -g "daemon off;" -c "/var/www/html/nginx.conf" &
/usr/sbin/sshd -D &
redis-server &

# Execute the command passed to the container
exec "$@"

## echo "127.0.0.1 $(hostname) localhost localhost.localdomain" >> /etc/hosts;
## service sendmail restart