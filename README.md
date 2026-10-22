# Dockerized NGINX + WordPress for Flux

A production-ready Docker image combining NGINX and WordPress with PHP-FPM, featuring configurable performance tiers and extensive customization options.

## Features

- NGINX web server with optimized configuration
- WordPress with PHP 8.x and PHP-FPM
- Multiple performance plans (Basic, Standard, Pro, Ultra, Enterprise)
- OPcache with JIT compilation support
- SFTP/SSH access with key-based authentication
- Automated WordPress cron via system cron
- Extensive environment variable configuration


## Performance Plans

The container supports 5 predefined performance tiers configured via the `PLAN` environment variable:

| Plan | Opcache Memory | Max Workers | PHP Memory | Best For |
|------|----------------|-------------|------------|----------|
| Basic | 8M JIT only | 10 | 5120M | Small sites, development |
| Standard | 256M | 20 | 5120M | Medium traffic sites |
| Pro | 512M | 30 | 5120M | High traffic sites |
| Ultra | 1024M | 40 | 5120M | Very high traffic |
| Enterprise | 2048M | 80 | 10240M | Enterprise applications |

## Environment Variables

### Core Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `PLAN` | Performance tier (Basic, Standard, Pro, Ultra, Enterprise) | `doNothing` |
| `PUBLIC_KEY` | SSH public key for SFTP/SSH access | - |
| `WP_CRON_INTERVAL` | WordPress cron interval in minutes | `15` |

### PHP Opcache Configuration

Override opcache settings for any plan:

| Variable | Description | Plan Defaults | Valid Values |
|----------|-------------|---------------|--------------|
| `PHP_OPCACHE_ENABLE` | Enable opcache | 1 (except Basic) | 0 or 1 |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | Memory for opcache (MB) | 256/512/1024/2048 | Integer (MB) |
| `PHP_OPCACHE_INTERNED_STRINGS_BUFFER` | Interned strings memory (MB) | 64/128/256 | Integer (MB) |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | Max cached files | 5000/15000/50000 | Integer |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | Check file timestamps | 1 | 0 or 1 |
| `PHP_OPCACHE_REVALIDATE_FREQ` | Revalidation frequency (seconds) | 60 | Integer |
| `PHP_OPCACHE_CONSISTENCY_CHECKS` | Consistency checks | 0 | 0 or 1 |
| `PHP_OPCACHE_SAVE_COMMENTS` | Save comments | 0 | 0 or 1 |
| `PHP_OPCACHE_ENABLE_FILE_OVERRIDE` | File override optimization | 1 | 0 or 1 |
| `PHP_OPCACHE_JIT` | JIT compilation mode | 1254 | See PHP docs |
| `PHP_OPCACHE_JIT_BUFFER_SIZE` | JIT buffer size | 8M/12M/16M | Memory value (e.g., 16M) |

### PHP Runtime Configuration

| Variable | Description | Plan Defaults | Valid Values |
|----------|-------------|---------------|--------------|
| `PHP_MAX_INPUT_VARS` | Maximum input variables | 3000/5000/10000 | Integer |
| `PHP_MEMORY_LIMIT` | PHP memory limit | 5120M/10240M | Memory value (e.g., 512M) |

### PHP-FPM Pool Configuration

Configure the PHP-FPM worker process pool:

| Variable | Description | Plan Defaults | Valid Values |
|----------|-------------|---------------|--------------|
| `PHP_FPM_MAX_CHILDREN` | Maximum child processes | 10/20/30/40/80 | Integer |
| `PHP_FPM_START_SERVERS` | Processes on startup | 2/4/6/8/16 | Integer |
| `PHP_FPM_MIN_SPARE_SERVERS` | Minimum idle processes | 1/2/3/4/8 | Integer |
| `PHP_FPM_MAX_SPARE_SERVERS` | Maximum idle processes | 3/6/9/12/24 | Integer |
| `PHP_FPM_MAX_REQUESTS` | Requests before restart | 500 | Integer |

## Usage Examples


### Custom Configuration Overrides

Override specific parameters while using a base plan:

```bash
docker run -d \
  -e PLAN=Pro \
  -e PHP_OPCACHE_MEMORY_CONSUMPTION=1024 \
  -e PHP_FPM_MAX_CHILDREN=50 \
  -e PHP_MEMORY_LIMIT=8192M \
  -p 80:80 \
  -v wordpress-data:/var/www/html \
  your-image-name
```

### Development Configuration

Disable opcache caching for development:

```bash
docker run -d \
  -e PLAN=Basic \
  -e PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
  -e PHP_OPCACHE_REVALIDATE_FREQ=0 \
  -p 80:80 \
  -v wordpress-data:/var/www/html \
  your-image-name
```

### Production High-Performance Setup

```bash
docker run -d \
  -e PLAN=Enterprise \
  -e PHP_OPCACHE_MEMORY_CONSUMPTION=4096 \
  -e PHP_FPM_MAX_CHILDREN=100 \
  -e PHP_FPM_START_SERVERS=25 \
  -e PUBLIC_KEY="ssh-rsa AAAAB3Nza..." \
  -e WP_CRON_INTERVAL=5 \
  -p 80:80 \
  -p 22:22 \
  -v wordpress-data:/var/www/html \
  your-image-name
```

## SSH/SFTP Access

The container includes two users for remote access:

- **sftpuser**: SFTP-only access to `/var/www/html`
- **sshuser**: Full SSH access

To enable access, provide your SSH public key via the `PUBLIC_KEY` environment variable:

```bash
docker run -d \
  -e PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..." \
  -p 22:22 \
  your-image-name
```

Connect via SFTP:
```bash
sftp -P 22 sftpuser@your-server
```

Connect via SSH:
```bash
ssh -p 22 sshuser@your-server
```

## WordPress Cron

WordPress cron is handled by the system cron daemon instead of PHP-based cron. Configure the interval:

```bash
docker run -d \
  -e WP_CRON_INTERVAL=10 \
  your-image-name
```

## Volume Mounts

Important paths to persist:

- `/var/www/html` - WordPress installation and wp-content
- `/var/www/html/nginx.conf` - NGINX configuration (auto-created)

## Configuration Files

The entrypoint script generates plan-specific configuration files at runtime:

- `/usr/local/etc/php/conf.d/zz-plan-opcache.ini` - Opcache settings
- `/usr/local/etc/php/conf.d/zz-plan-php.ini` - PHP runtime settings
- `/usr/local/etc/php-fpm.d/zz-plan-pool.conf` - PHP-FPM pool settings

These files are regenerated on each container start, allowing you to change plans without rebuilding the image.

## Performance Tuning Tips

### For High Traffic Sites

1. Use Pro, Ultra, or Enterprise plans
2. Increase `PHP_FPM_MAX_CHILDREN` based on available RAM
3. Monitor opcache usage and adjust `PHP_OPCACHE_MEMORY_CONSUMPTION`
4. Set `PHP_OPCACHE_VALIDATE_TIMESTAMPS=0` for maximum performance (production only)

### For Development

1. Use Basic or Standard plan
2. Set `PHP_OPCACHE_REVALIDATE_FREQ=0` for immediate code changes
3. Enable `PHP_OPCACHE_VALIDATE_TIMESTAMPS=1`

### Memory Calculations

PHP-FPM memory usage formula:
```
Total Memory = PHP_FPM_MAX_CHILDREN × (average PHP process memory)
```

Ensure your container/host has sufficient RAM for your configuration.

## Troubleshooting

### Check Plan Configuration

```bash
docker exec your-container cat /usr/local/etc/php/conf.d/zz-plan-opcache.ini
docker exec your-container cat /usr/local/etc/php/conf.d/zz-plan-php.ini
docker exec your-container cat /usr/local/etc/php-fpm.d/zz-plan-pool.conf
```

### View Opcache Status

Create a PHP file in your WordPress installation:
```php
<?php phpinfo(); ?>
```

### Check PHP-FPM Status

```bash
docker exec your-container ps aux | grep php-fpm
```

## License

This project configuration is provided as-is for use with WordPress and NGINX.
