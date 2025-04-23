ARG BASE_IMAGE
FROM ${BASE_IMAGE}
# update to v.6.3.1
# install nginx

RUN apt-get update && apt-get install -y nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Set the working directory to /var/www/html
WORKDIR /var/www/



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
    echo 'upload_max_filesize = 512M'; \
    echo 'post_max_size = 512M'; \
    echo 'memory_limit = 512M'; \
    echo 'max_execution_time=600s'; \
	} > /usr/local/etc/php/conf.d/extra.ini

  # PHP-FPM configs
RUN { \
    echo '[global]'; \
    echo 'error_log = /var/log/php-fpm-error.log'; \
    echo 'emergency_restart_threshold=3'; \
    echo 'emergency_restart_interval=1m'; \
    echo 'process_control_timeout=5s'; \
    echo '[www]'; \
    echo 'request_terminate_timeout=600s'; \
	} > /usr/local/etc/php-fpm.d/zzz-extra.conf

# Install OpenSSH server and SFTP server
 RUN apt-get update && \
   apt-get install -y openssh-server openssh-sftp-server && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install MySQL client
RUN apt-get update && apt-get install -y default-mysql-client nano

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Install Redis server package
RUN apt-get install -y redis-server

# Install php-redis extension
RUN pecl install redis \
&& docker-php-ext-enable redis

#Configure SSH server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    echo "Match User sftpuser" >> /etc/ssh/sshd_config && \
    echo "    ChrootDirectory /var/www/" >> /etc/ssh/sshd_config && \
    echo "    X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "    AllowTcpForwarding no" >> /etc/ssh/sshd_config && \
    echo "    ForceCommand internal-sftp" >> /etc/ssh/sshd_config

RUN groupadd sshgroup && useradd -ms /bin/bash -g sshgroup sshuser
RUN mkdir -p /home/sshuser/.ssh


RUN mkdir -p /var/run/sshd && \
    echo "mkdir -p /var/run/sshd" >> /etc/rc.local

# Create a group for SFTP users and add www-data to it
#RUN usermod -a -G www-data root

# Set permissions for wp-content folder
RUN \
	chown -R www-data:www-data /var/www/html/ ;\
	chmod -R 777 /var/www/html/
RUN chmod -R g+rwx /var/www/html/

# Copy the Nginx configuration file into the container at /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf
# Add wordpress config and database env
COPY --chown=www-data:www-data wp-config.php /usr/src/wordpress/wp-config.php
# ENV WORDPRESS_DB_USER=root
# ENV WORDPRESS_DB_NAME=test_db

# Add wordpress entrypoint
COPY docker-entrypoint.sh /usr/local/docker-entrypoint.sh
RUN chmod +x /usr/local/docker-entrypoint.sh
# Add php-fpm service
COPY php-fpm.sh /usr/local/php-fpm.sh
RUN chmod +x /usr/local/php-fpm.sh

# Expose port 80 for Nginx
EXPOSE 80
# Expose the SFTP server port
EXPOSE 2222/tcp

ENTRYPOINT ["/usr/local/docker-entrypoint.sh"]
# Start PHP-FPM and Nginx servers
CMD /usr/local/php-fpm.sh & nginx -g "daemon off;" -c "/var/www/html/nginx.conf" & /usr/sbin/sshd -D & redis-server
