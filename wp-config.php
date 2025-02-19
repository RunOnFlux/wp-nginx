<?php
// VERSION:1.0.0
define( 'WP_CACHE', true );

/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * This has been slightly modified (to read environment variables) for use in Docker.
 *
 * @link https://wordpress.org/support/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// IMPORTANT: this file needs to stay in-sync with https://github.com/WordPress/WordPress/blob/master/wp-config-sample.php
// (it gets parsed by the upstream wizard in https://github.com/WordPress/WordPress/blob/f27cb65e1ef25d11b535695a660e7282b98eb742/wp-admin/setup-config.php#L356-L392)

// a helper function to lookup "env_FILE", "env", then fallback
if ( !function_exists('getenv_docker') ) {
	// https://github.com/docker-library/wordpress/issues/588 (WP-CLI will load this file 2x)
	function getenv_docker( $env, $default ) {
		if ( $fileEnv = getenv( $env . '_FILE') ) {
			return rtrim( file_get_contents( $fileEnv ), "\r\n" );
		}
		else if ( ( $val = getenv( $env ) ) !== false ) {
			return $val;
		}
		else {
			return $default;
		}
	}
}

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', getenv_docker('WORDPRESS_DB_NAME', 'test_db') );

/** Database username */
define( 'DB_USER', getenv_docker('WORDPRESS_DB_USER', 'root') );

/** Database password */
define( 'DB_PASSWORD', getenv_docker('WORDPRESS_DB_PASSWORD', '123secret') );

/**
 * Docker image fallback values above are sourced from the official WordPress installation wizard:
 * https://github.com/WordPress/WordPress/blob/f9cc35ebad82753e9c86de322ea5c76a9001c7e2/wp-admin/setup-config.php#L216-L230
 * (However, using "example username" and "example password" in your database is strongly discouraged.  Please use strong, random credentials!)
 */

/** Database hostname */
define( 'DB_HOST', getenv_docker('WORDPRESS_DB_HOST', '') );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', getenv_docker('WORDPRESS_DB_CHARSET', 'utf8') );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', getenv_docker('WORDPRESS_DB_COLLATE', '') );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define( 'AUTH_KEY',         getenv_docker('WORDPRESS_AUTH_KEY',         '974cc9361d6797c406263e709b176264348f1da3') );
define( 'SECURE_AUTH_KEY',  getenv_docker('WORDPRESS_SECURE_AUTH_KEY',  'f2208cc4d72c724cee71aa30a902a5191446f593') );
define( 'LOGGED_IN_KEY',    getenv_docker('WORDPRESS_LOGGED_IN_KEY',    '352d82ef04e4a5413e19db8592c39411919d2c85') );
define( 'NONCE_KEY',        getenv_docker('WORDPRESS_NONCE_KEY',        'ece871740627976abf36b6fd1edfcfd78d0550db') );
define( 'AUTH_SALT',        getenv_docker('WORDPRESS_AUTH_SALT',        '645e4ea04429a04f219a5732f71b77ca9b50402a') );
define( 'SECURE_AUTH_SALT', getenv_docker('WORDPRESS_SECURE_AUTH_SALT', '000a1524071c9fd81c2f2be043a997a0e94675c4') );
define( 'LOGGED_IN_SALT',   getenv_docker('WORDPRESS_LOGGED_IN_SALT',   '57e76ae81687414e8f7c37c90afae63f9b8a5d6a') );
define( 'NONCE_SALT',       getenv_docker('WORDPRESS_NONCE_SALT',       'bd0b3f068e3e4eac8bb6fbc89dc7ba3744eb2a54') );
// (See also https://wordpress.stackexchange.com/a/152905/199287)

/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = getenv_docker('WORDPRESS_TABLE_PREFIX', 'wp_');

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/support/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', !!getenv_docker('WORDPRESS_DEBUG', '') );
/* Add any custom values between this line and the "stop editing" line. */

// Check DB connection
$is_slave = true;
$tries = 0;
$maxtries = 30;
// if(empty($_SERVER['HTTP_HOST'])) $maxtries = 1;

while ($tries < $maxtries) {
    try {
        $mysqli = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

        // If connected, check if the database exists
        $query = "SELECT count(*) FROM " . DB_NAME . "." . $table_prefix . "options";
        $result = $mysqli->query($query);

        if ($result && $result->num_rows > 0) {
            // Database exists, define constants and close the connection
            define('WP_AUTO_UPDATE_CORE', 'minor');
            $is_slave = false;
            $mysqli->close();
            break;
        } else {
            // Database does not exist, increment tries and wait before retrying
            $tries += 1;
            sleep(1);
        }

        $result->close();
        $mysqli->close();
    } catch (mysqli_sql_exception $e) {
        // Connection failed, increment tries and wait before retrying
        $tries += 1;
        sleep(1);
    }
}
if ( $is_slave ) {
  if(empty($_SERVER['HTTP_HOST'])) { // FDM requests
    header('HTTP/1.1 500 Internal Server Error');
  } else { // non fdm requests
    define('DISABLE_WP_CRON', true);
    define('WP_AUTO_UPDATE_CORE', false);
    header('HTTP/1.1 503 Service Unavailable');
    echo 'Standby node. Runs on <a href="https://runonflux.io">Flux</a>';
  }
  exit(0);
}
// If we're behind a proxy server and using HTTPS, we need to alert WordPress of that fact
// see also https://wordpress.org/support/article/administration-over-ssl/#using-a-reverse-proxy
if ( !empty( $_SERVER['HTTP_HOST'] ) || $_SERVER['REMOTE_ADDR'] === '127.0.0.1' ) {
  if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https' ) !== false ) {
    $_SERVER['HTTPS'] = 'on';
  } else {
    // define( 'WP_HOME', 'http://' . $_SERVER['HTTP_HOST'] . '/' );
    // define( 'WP_SITEURL', 'http://' . $_SERVER['HTTP_HOST'] . '/' );
  }
} else {
    // request comming from FDM health check, check if node is slave
    echo 'OK';
    exit(0);
}

define( 'WP_MEMORY_LIMIT', '1024M' );

# define( 'WP_DEBUG', true);
# define( 'WP_DEBUG_LOG', true );
/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';

