#!/bin/bash
set -e
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1

# Get config
DATADIR="$("mysqld" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
if [ ! -e "$DATADIR/init.ok" ]; then
  if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
    echo >&2 'error: database is uninitialized and password option is not specified '
    echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
    exit 1
  fi

  mkdir -p "$DATADIR"
  echo 'Running mysql initialize'
  mysqld --initialize-insecure --datadir="$DATADIR"
  chown -R mysql:mysql "$DATADIR"

  service mysql start
  while [ ! -e "/var/run/mysqld/mysqld.sock" ]; do ( sleep 0.1 ) done

  echo "Enabling tokudb..."
  mysql -e "INSTALL PLUGIN tokudb SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_file_map SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_fractal_tree_info SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_fractal_tree_block_map SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_trx SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_locks SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_lock_waits SONAME 'ha_tokudb.so';
  INSTALL PLUGIN tokudb_background_job_status SONAME 'ha_tokudb.so';
  " &> /dev/null
  # GENERATE RANDOM PASSWORD
  if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
      MYSQL_ROOT_PASSWORD="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo '')"
      echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
  fi

  echo "Adding default users..."
  mysql -u root -e "DELETE FROM mysql.user;"
  mysql -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
  mysql -u root -e "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;"
  mysql -u root -e "DROP DATABASE IF EXISTS test; FLUSH PRIVILEGES;"

  if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
    mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;"
    if [ "$MYSQL_DATABASE" ]; then
      mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON \`"$MYSQL_DATABASE"\`.* TO '"$MYSQL_USER"'@'%' ;"
    fi
    mysql -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
  fi

  if [ "$MYSQL_DATABASE" ]; then
    echo "Adding default database..."
    mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;"
  fi

  service mysql stop &> /dev/null
  echo 'Finished mysql initialize'

fi

echo "Starting mysql daemon..."
touch $DATADIR/init.ok
chown -R mysql:mysql "$DATADIR"
mysqld $@
