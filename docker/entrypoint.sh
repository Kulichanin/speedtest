#!/bin/bash

set -e
# Disable print commands and their arguments as they are executed.
# set -x

# Path for file conf
CONFIG_FILE="/vault/secrets/config.env"

if [ -f "$CONFIG_FILE" ]; then
  echo "Read file config.env"
  set -o allexport
  source "$CONFIG_FILE"
  set +o allexport
else
  echo "File config.env not found. Export environments in shell."
fi

# Cleanup
rm -rf /var/www/html/*

# Copy frontend files
cp -v *.js /var/www/html/

# Copy favicon
cp -v favicon.ico /var/www/html/

# Set up backend side for standlone modes
if [[ "$MODE" == "standalone" || "$MODE" == "dual" ]]; then
  echo "Set up standlone modes"
  cp -rv backend/ /var/www/html/backend
  if [ ! -z "$IPINFO_APIKEY" ]; then
    sed -i s/\$IPINFO_APIKEY\ =\ \'\'/\$IPINFO_APIKEY\ =\ \'$IPINFO_APIKEY\'/g /var/www/html/backend/getIP_ipInfo_apikey.php
  fi
fi

if [ "$MODE" == "backend" ]; then
  echo " Set up backend side"
  cp -rv backend/* /var/www/html
  if [ ! -z "$IPINFO_APIKEY" ]; then
    echo "Use IPINFO_APIKEY"
    sed -i s/\$IPINFO_APIKEY\ =\ \'\'/\$IPINFO_APIKEY\ =\ \'$IPINFO_APIKEY\'/g /var/www/html/getIP_ipInfo_apikey.php
  fi
fi

# Set up unified index.php and copy servers.json file
if [ "$MODE" != "backend" ]; then
  echo "Set up unified index.php and copy servers.json file"
  cp -v /etc/app/servers.json /servers.json
  cp -v docker/ui.php /var/www/html/index.php
fi

# Apply Telemetry settings when running in standalone or frontend mode and telemetry is enabled
if [[ "$TELEMETRY" == "true" && ( "$MODE" == "frontend" || "$MODE" == "standalone" || "$MODE" == "dual" ) ]]; then
  echo "Apply Telemetry settings when running in standalone or frontend mode and telemetry is enabled"
  cp -vr results /var/www/html/results

  if [ "$MODE" == "frontend" ]; then
    mkdir /var/www/html/backend
    cp -v backend/getIP_util.php /var/www/html/backend
  fi

 # Defining database types
  case $DB_TYPE in

    "mysql")
      echo "Use mysql database"
      sed -i 's/$DB_TYPE = '\''.*'\''/$DB_TYPE = '\'$DB_TYPE\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$MySql_username = '\''.*'\''/$MySql_username = '\'$DB_USERNAME\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$MySql_password = '\''.*'\''/$MySql_password = '\'$DB_PASSWORD\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$MySql_hostname = '\''.*'\''/$MySql_hostname = '\'$DB_HOSTNAME\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$MySql_databasename = '\''.*'\''/$MySql_databasename = '\'$DB_NAME\''/g' /var/www/html/results/telemetry_settings.php

      # Query to check table existence
      QUERY="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME' AND table_name = 'speedtest_users';"

      # Executing a query through mysql
      RESULT=$(mysql -u $DB_USERNAME -p$DB_PASSWORD -h $DB_HOSTNAME $DB_NAME -Bse "$QUERY")

      if [ "$RESULT" -eq 0 ]; then
          echo "Table spedtest_user not in in $DB_NAME"
          echo "Create table"
          mysql -u $DB_USERNAME -p$DB_PASSWORD -h $DB_HOSTNAME $DB_NAME < results/telemetry_mysql.sql
      else
          echo "Table spedtest_user already exists in $DB_NAME"
      fi
      ;;

    "postgresql")
      echo "Use postgress database"
      sed -i 's/$DB_TYPE = '\''.*'\''/$DB_TYPE = '\'$DB_TYPE\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$PostgreSql_username = '\''.*'\''/$PostgreSql_username = '\'$DB_USERNAME\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$PostgreSql_password = '\''.*'\''/$PostgreSql_password = '\'$DB_PASSWORD\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$PostgreSql_hostname = '\''.*'\''/$PostgreSql_hostname = '\'$DB_HOSTNAME\''/g' /var/www/html/results/telemetry_settings.php
      sed -i 's/$PostgreSql_databasename = '\''.*'\''/$PostgreSql_databasename = '\'$DB_NAME\''/g' /var/www/html/results/telemetry_settings.php
      
      # Executing a query through psql
      RESULT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOSTNAME -U $DB_USERNAME -d "$DB_NAME" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'speedtest_users')")

      if [ "$RESULT" -eq 0 ]; then
          echo "Table spedtest_user not in in $DB_NAME"
          echo "Create table"
          PGPASSWORD=$DB_PASSWORD psql -h $DB_HOSTNAME -U $DB_USERNAME $DB_NAME < results/telemetry_postgresql.sql 
      else
          echo "Table spedtest_user already exists in $DB_NAME"
      fi
      ;;

    "sqlite")
      echo "Use sqlite database"
      sed -i s/\$Sqlite_db_file\ =\ \".*\"/\$Sqlite_db_file=\"\\\/database\\\/db.sql\"/g /var/www/html/results/telemetry_settings.php
      mkdir -p /database/
      chown www-data /database/
      ;;    
    *)
      echo "Failed to resolve database type! Use DB_TYPE variable environment!"
      exit 1
      ;;
  esac
  
  sed -i s/\$stats_password\ =\ \'.*\'/\$stats_password\ =\ \'$PASSWORD\'/g /var/www/html/results/telemetry_settings.php

  if [ "$ENABLE_ID_OBFUSCATION" == "true" ]; then
    sed -i s/\$enable_id_obfuscation\ =\ .*\;/\$enable_id_obfuscation\ =\ true\;/g /var/www/html/results/telemetry_settings.php
  fi

  if [ "$REDACT_IP_ADDRESSES" == "true" ]; then
    sed -i s/\$redact_ip_addresses\ =\ .*\;/\$redact_ip_addresses\ =\ true\;/g /var/www/html/results/telemetry_settings.php
  fi

fi

echo "Done, Starting php-fpm!"

# Runs php-fpm
php-fpm