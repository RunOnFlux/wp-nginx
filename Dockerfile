FROM wordpress:fpm

# install nginx

ENV NGINX_VERSION   1.23.3
ENV NJS_VERSION     0.7.9
ENV PKG_RELEASE     1~bullseye

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system --gid 101 nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
    " \
    && case "$dpkgArch" in \
        amd64|arm64) \
# arches officialy built by upstream
            echo "deb https://nginx.org/packages/mainline/debian/ bullseye nginx" >> /etc/apt/sources.list.d/nginx.list \
            && apt-get update \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published source packages
            echo "deb-src https://nginx.org/packages/mainline/debian/ bullseye nginx" >> /etc/apt/sources.list.d/nginx.list \
            \
# new directory for storing sources and .deb files
            && tempDir="$(mktemp -d)" \
            && chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
            \
# save list of currently-installed packages so build dependencies can be cleanly removed later
            && savedAptMark="$(apt-mark showmanual)" \
            \
# build .deb files from upstream's source packages (which are verified by apt-get)
            && apt-get update \
            && apt-get build-dep -y $nginxPackages \
            && ( \
                cd "$tempDir" \
                && DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
                    apt-get source --compile $nginxPackages \
            ) \
# we don't remove APT lists here because they get re-downloaded and removed later
            \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
            && apt-mark showmanual | xargs apt-mark auto > /dev/null \
            && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
            \
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
            && ls -lAFh "$tempDir" \
            && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
            && grep '^Package: ' "$tempDir/Packages" \
            && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
            && apt-get -o Acquire::GzipIndexes=false update \
            ;; \
    esac \
    \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
                        curl \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d


# Set the working directory to /var/www/html
WORKDIR /var/www/html



# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN set -eux; \
	docker-php-ext-enable opcache; \
	{ \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini
# PHP upload size
RUN { \
    echo 'upload_max_filesize = 256M'; \
    echo 'post_max_size = 256M'; \
    echo 'memory_limit = 256M'; \
	} > /usr/local/etc/php/conf.d/extra.ini

  # PHP-FPM configs
RUN { \
    echo '[global]'; \
    echo 'emergency_restart_threshold=3'; \
    echo 'emergency_restart_interval=1m'; \
    echo 'process_control_timeout=5s'; \
	} > /usr/local/etc/php-fpm.d/zzz-extra.conf

# Install OpenSSH server and SFTP server
 RUN apt-get update && \
   apt-get install -y openssh-server openssh-sftp-server && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure SSH server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    echo "Match Group sftp" >> /etc/ssh/sshd_config && \
    echo "    ChrootDirectory /var/www/" >> /etc/ssh/sshd_config && \
    echo "    X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config && \
    echo "    ForceCommand internal-sftp" >> /etc/ssh/sshd_config

RUN mkdir -p /var/run/sshd && \
    echo "mkdir -p /var/run/sshd" >> /etc/rc.local

# Create a group for SFTP users and add www-data to it
RUN usermod -a -G www-data root

# Set permissions for wp-content folder
RUN \
	chown -R www-data:www-data /var/www/html/wp-content ;\
	chmod -R 777 /var/www/html/wp-content

# Copy the Nginx configuration file into the container at /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf
# Add wordpress config and database env
COPY --chown=www-data:www-data wp-config.php /var/www/html/wp-config.php
ENV WORDPRESS_DB_USER=root
ENV WORDPRESS_DB_NAME=test_db
# Add wordpress entrypoint
COPY docker-entrypoint.sh /usr/local/docker-entrypoint.sh
RUN chmod +x /usr/local/docker-entrypoint.sh
# Add php-fpm service
COPY php-fpm.sh /usr/local/php-fpm.sh
RUN chmod +x /usr/local/php-fpm.sh

VOLUME /var/www/html
# Expose port 80 for Nginx
EXPOSE 80
# Expose the SFTP server port
EXPOSE 22/tcp

ENTRYPOINT ["/usr/local/docker-entrypoint.sh"]
# Start PHP-FPM and Nginx servers
CMD /usr/local/php-fpm.sh & nginx -g "daemon off;" -c "/etc/nginx/nginx.conf"
