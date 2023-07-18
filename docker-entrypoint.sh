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
tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
echo >&2 "Complete! WordPress has been successfully copied to $PWD"

# Add the public key to the authorized keys file
mkdir -p /var/www/html/wp-content/.ssh && \
echo "$PUBLIC_KEY" > /var/www/html/wp-content/.ssh/authorized_keys && \
chmod 600 /root/.ssh/authorized_keys && \
chown root:root /root/.ssh/authorized_keys

exec "$@"

## echo "127.0.0.1 $(hostname) localhost localhost.localdomain" >> /etc/hosts;
## service sendmail restart