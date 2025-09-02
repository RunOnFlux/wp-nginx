#!/usr/bin/env bash

set -Eeuo pipefail

# WordPress source and target arguments for tar
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

# Copy WordPress files if not already present
if [ -d "/var/www/html/wp-admin" ] && [ -f "/var/www/html/wp-config.php" ] && [ -f "/var/www/html/index.php" ]; then
    echo "Wordpress already there skipping..."
else
    tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
    echo >&2 "Complete! WordPress has been successfully copied to $PWD"
fi

# Replace wp-config if new version is released
SOURCE_CONFIG_FILE="/usr/src/wordpress/wp-config.php"
TARGET_CONFIG_FILE="/var/www/html/wp-config.php"
OLD_HASH="8a4a780b92ec2112ed7a74b33ae4420b"
NEW_HASH="82235206f8c97f86e9a21adfa346fdd9"
STATUS_FILE="/var/www/html/status.txt"

# Check if the target file exists
if [[ -f "$TARGET_CONFIG_FILE" ]]; then
    # fix the query
    sed -i.bak '/\$query = "SELECT count(\*) FROM " \. DB_NAME \. "\." \. \$table_prefix \. "options";/c\$query = "SELECT count(*) FROM flux_backlog.options";' "$TARGET_CONFIG_FILE"
    # Calculate the MD5 hash of wp-config.php
    CURRENT_HASH=$(md5sum /var/www/html/wp-config.php | awk '{print $1}')
    echo "File $TARGET_CONFIG_FILE exists, hash:$CURRENT_HASH"
    # Compare the hashes
    if [ "$CURRENT_HASH" = "$OLD_HASH" ]; then
        echo "File $TARGET_CONFIG_FILE matches old hash, replacing the file..."
        cp "$SOURCE_CONFIG_FILE" "$TARGET_CONFIG_FILE"
    elif [ "$CURRENT_HASH" = "$NEW_HASH" ]; then
        echo "File $TARGET_CONFIG_FILE has new hash. Nothing to do."
    elif [[ -f "$STATUS_FILE" ]]; then
        echo "Status file exists. Nothing to do."
    else
        echo "File $TARGET_CONFIG_FILE does not match any hash, creating a flag file."
        echo "v1" > "$STATUS_FILE"
    fi
else
    echo "File $TARGET_CONFIG_FILE does not exist."
    echo "Copying $SOURCE_CONFIG_FILE to $TARGET_CONFIG_FILE."
    cp "$SOURCE_CONFIG_FILE" "$TARGET_CONFIG_FILE"
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

# Read the PLAN environment variable. Default to "doNothing" if not set.
CURRENT_PLAN="${PLAN:-doNothing}"

echo "--- Configuring PHP for PLAN=${CURRENT_PLAN} ---"

PHP_INI_DIR="/usr/local/etc/php/conf.d"
PLAN_OPCACHE_CONF_FILE="${PHP_INI_DIR}/zz-plan-opcache.ini"
PLAN_PHP_CONF_FILE="${PHP_INI_DIR}/zz-plan-php.ini"

# Clear previous plan specific configs if any, to handle container restarts with different PLAN values.
rm -f "${PLAN_OPCACHE_CONF_FILE}" "${PLAN_PHP_CONF_FILE}"

# Apply plan-specific PHP configurations
if [ "${CURRENT_PLAN}" = "Basic" ]; then
    {
        echo '; -- Basic Plan Opcache Settings (Runtime) --';
        echo 'opcache.jit=1254';
        echo 'opcache.jit_buffer_size=8M';
    } > "${PLAN_OPCACHE_CONF_FILE}" && \
    {
        echo '; -- Basic Plan PHP Settings (Runtime) --';
        echo 'max_input_vars=3000';
        echo 'memory_limit=1024M';
    } > "${PLAN_PHP_CONF_FILE}"
elif [ "${CURRENT_PLAN}" = "Standard" ]; then
    {
        echo '; -- Standard Plan Opcache Settings (Runtime) --';
        echo 'opcache.enable=1';
        echo 'opcache.memory_consumption=256';
        echo 'opcache.interned_strings_buffer=64';
        echo 'opcache.max_accelerated_files=5000';
        echo 'opcache.validate_timestamps=1';
        echo 'opcache.revalidate_freq=60';
        echo 'opcache.consistency_checks=0';
        echo 'opcache.save_comments=0';
        echo 'opcache.enable_file_override=1';
        echo 'opcache.jit=1254';
        echo 'opcache.jit_buffer_size=8M';
    } > "${PLAN_OPCACHE_CONF_FILE}" && \
    {
        echo '; -- Standard Plan PHP Settings (Runtime) --';
        echo 'max_input_vars=5000';
        echo 'memory_limit=2048M';
    } > "${PLAN_PHP_CONF_FILE}"
elif [ "${CURRENT_PLAN}" = "Pro" ]; then
    {
        echo '; -- Pro Plan Opcache Settings (Runtime) --';
        echo 'opcache.enable=1';
        echo 'opcache.memory_consumption=512';
        echo 'opcache.interned_strings_buffer=128';
        echo 'opcache.max_accelerated_files=15000';
        echo 'opcache.validate_timestamps=1';
        echo 'opcache.revalidate_freq=60';
        echo 'opcache.consistency_checks=0';
        echo 'opcache.save_comments=0';
        echo 'opcache.enable_file_override=1';
        echo 'opcache.jit=1254';
        echo 'opcache.jit_buffer_size=12M';
    } > "${PLAN_OPCACHE_CONF_FILE}" && \
    {
        echo '; -- Pro Plan PHP Settings (Runtime) --';
        echo 'max_input_vars=10000';
        echo 'memory_limit=4096M';
    } > "${PLAN_PHP_CONF_FILE}"
elif [ "${CURRENT_PLAN}" = "Ultra" ]; then
    {
        echo '; -- Ultra Plan Opcache Settings (Runtime) --';
        echo 'opcache.enable=1';
        echo 'opcache.memory_consumption=1024';
        echo 'opcache.interned_strings_buffer=256';
        echo 'opcache.max_accelerated_files=50000';
        echo 'opcache.validate_timestamps=1';
        echo 'opcache.revalidate_freq=60';
        echo 'opcache.consistency_checks=0';
        echo 'opcache.save_comments=0';
        echo 'opcache.enable_file_override=1';
        echo 'opcache.jit=1254';
        echo 'opcache.jit_buffer_size=12M';
    } > "${PLAN_OPCACHE_CONF_FILE}" && \
    {
        echo '; -- Ultra Plan PHP Settings (Runtime) --';
        echo 'max_input_vars=10000';
        echo 'memory_limit=5120M';
    } > "${PLAN_PHP_CONF_FILE}"
elif [ "${CURRENT_PLAN}" = "Enterprise" ]; then
    {
        echo '; -- Enterprise Plan Opcache Settings (Runtime) --';
        echo 'opcache.enable=1';
        echo 'opcache.memory_consumption=2048';
        echo 'opcache.interned_strings_buffer=256';
        echo 'opcache.max_accelerated_files=50000';
        echo 'opcache.validate_timestamps=1';
        echo 'opcache.revalidate_freq=60';
        echo 'opcache.consistency_checks=0';
        echo 'opcache.save_comments=0';
        echo 'opcache.enable_file_override=1';
        echo 'opcache.jit=1254';
        echo 'opcache.jit_buffer_size=16M';
    } > "${PLAN_OPCACHE_CONF_FILE}" && \
    {
        echo '; -- Enterprise Plan PHP Settings (Runtime) --';
        echo 'max_input_vars=10000';
        echo 'memory_limit=10240M';
    } > "${PLAN_PHP_CONF_FILE}"
else
    echo "WARNING: Unknown PLAN='${CURRENT_PLAN}'. No specific PHP configurations applied. Using defaults from other .ini files." >&2
    # Create empty files to prevent errors if PHP expects them,
    # or to ensure default values from other files are used.
    # Alternatively, you could copy a default minimal config here.
    touch "${PLAN_OPCACHE_CONF_FILE}"
    touch "${PLAN_PHP_CONF_FILE}"
fi

echo "--- Docker Entrypoint: PHP configuration complete for PLAN=${CURRENT_PLAN} ---"


# --- Configure WP_MEMORY_LIMIT in wp-config.php based on PLAN ---
# TARGET_CONFIG_FILE is already defined as /var/www/html/wp-config.php
if [ -f "$TARGET_CONFIG_FILE" ]; then
    echo "--- Configuring WP_MEMORY_LIMIT for PLAN=${CURRENT_PLAN} in ${TARGET_CONFIG_FILE} ---"
    WP_MEMORY_VALUE=""

    if [ "${CURRENT_PLAN}" = "Basic" ]; then
        WP_MEMORY_VALUE="1024M"
    elif [ "${CURRENT_PLAN}" = "Standard" ]; then
        WP_MEMORY_VALUE="2048M"
    elif [ "${CURRENT_PLAN}" = "Pro" ]; then
        WP_MEMORY_VALUE="4096M"
    elif [ "${CURRENT_PLAN}" = "Ultra" ]; then
        WP_MEMORY_VALUE="5120M"
    elif [ "${CURRENT_PLAN}" = "Enterprise" ]; then
        WP_MEMORY_VALUE="10240M"
    fi

    if [ -n "$WP_MEMORY_VALUE" ]; then
        # Check if WP_MEMORY_LIMIT is already defined
        if grep -q "define( *'WP_MEMORY_LIMIT'" "$TARGET_CONFIG_FILE"; then
            # It's defined, so replace it
            sed -i.bak "s/define( *'WP_MEMORY_LIMIT' *, *'.*' *);/define( 'WP_MEMORY_LIMIT', '${WP_MEMORY_VALUE}' );/" "$TARGET_CONFIG_FILE"
            echo "WP_MEMORY_LIMIT updated to ${WP_MEMORY_VALUE} in ${TARGET_CONFIG_FILE}"
        else
            # It's not defined, so add it before "/* That's all, stop editing! Happy publishing. */"
            if grep -q "/\* That's all, stop editing! Happy publishing. \*/" "$TARGET_CONFIG_FILE"; then
                 sed -i.bak "/\/\* That's all, stop editing! Happy publishing. \*\//i define( 'WP_MEMORY_LIMIT', '${WP_MEMORY_VALUE}' );\n" "$TARGET_CONFIG_FILE"
                 echo "WP_MEMORY_LIMIT added as ${WP_MEMORY_VALUE} in ${TARGET_CONFIG_FILE}"
            else
                # Fallback: append if the "stop editing" line isn't found (less ideal)
                echo "define( 'WP_MEMORY_LIMIT', '${WP_MEMORY_VALUE}' );" >> "$TARGET_CONFIG_FILE"
                echo "WP_MEMORY_LIMIT appended as ${WP_MEMORY_VALUE} to ${TARGET_CONFIG_FILE} (standard marker not found)"
            fi
        fi
    else
        echo "No specific WP_MEMORY_LIMIT defined for PLAN=${CURRENT_PLAN}. Existing value (or WordPress default) in ${TARGET_CONFIG_FILE} will be used."
    fi
else
    echo "WARNING: ${TARGET_CONFIG_FILE} not found. Cannot configure WP_MEMORY_LIMIT."
fi
# --- End WP_MEMORY_LIMIT configuration ---


# --- Setup cron job for WordPress scheduled tasks ---
CRON_INTERVAL="${WP_CRON_INTERVAL:-15}" # in minutes, default to 15 if not set
CRON_FILE="/etc/cron.d/wp-cron"
CRON_JOB="*/${CRON_INTERVAL} * * * * www-data curl -fsS http://localhost/wp-cron.php > /dev/null 2>&1"

# Only add/update the cron job if needed
if [ ! -f "$CRON_FILE" ] || ! grep -Fxq "$CRON_JOB" "$CRON_FILE"; then
    echo "$CRON_JOB" > "$CRON_FILE"
    chmod 0644 "$CRON_FILE"
    crontab -u www-data "$CRON_FILE"
    echo "WP-Cron job set to every ${CRON_INTERVAL} minutes."
else
    echo "WP-Cron job already set for every ${CRON_INTERVAL} minutes."
fi

service cron start

exec "$@"

## echo "127.0.0.1 $(hostname) localhost localhost.localdomain" >> /etc/hosts;
## service sendmail restart