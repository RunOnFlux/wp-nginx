## Dockerized NGINX + WordPress for Flux

### Usage
For local tests, generate a ssh key pair and set the public key in `PUBLIC_KEY` ENV
```
docker build -t wp-enginx-sftp:latest
docker run -d --name wp -p 8080:80 -p 2222:22 --env PUBLIC_KEY="ssh-rsa AA...wG/ rsa-key-20230115" --env WORDPRESS_DB_HOST=host.docker.internal:3306 --env WORDPRESS_DB_PASSWORD=secret --restart always --volume wp_data:/var/www/html/wp-content wp-enginx-sftp
```