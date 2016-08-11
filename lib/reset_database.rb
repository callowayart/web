#!/usr/bin/env ruby

def reset_database
  command %{
    export MYSQL_PWD=mysecretpassword
    path=/docker/shared/application/callowayart.com
    database=devbrand_wdp-103964
    (
      sudo rm -rf $path/*
      sudo mkdir -p $path
      sudo chmod -R g+w $path
    ) > /dev/null 2>&1

    # expand application
    aws s3 cp s3://callowayart/artifacts/wp-brandefined.tgz /tmp/wp.tgz
    sudo tar -xvzf /tmp/wp.tgz -C $path > /dev/null 2>&1
    cp -rf ./application/callowayart.com `dirname $path`

    # drop database and recreate
    mysql \
      -uroot \
      -P 3306 \
      -h `cat /tmp/mysql-ip` \
      -e "
        DROP DATABASE IF EXISTS \\\`$database\\\`;
        CREATE DATABASE \\\`$database\\\`;
      "

    # import against mysql
    sql=`ls $path/*.sql`
    mysql \
      -uroot \
      -P 3306 \
      -h `cat /tmp/mysql-ip` \
      -D $database \
        < $sql

    # create wordpress_callowayart database
    aws s3 cp s3://callowayart/artifacts/wordpress-callowayart.sql.tgz /tmp
    sudo tar -xvz \
      -f /tmp/wordpress-callowayart.sql.tgz \
      -C /tmp/wordpress-callowayart.sql \
        > /dev/null 2>&1

    mysql \
      -uroot \
      -P 3306 \
      -h `cat /tmp/mysql-ip` \
      -e "
        DROP DATABASE IF EXISTS wordpress_callowayart;
        CREATE DATABASE wordpress_callowayart;
      "
    sql=`ls $path/*.sql`
    mysql \
      -uroot \
      -P 3306 \
      -h `cat /tmp/mysql-ip` \
      -D wordpress_callowayart \
        < /tmp/wordpress-callowayart.sql

    # update site address
    # TODO: this a temporary measure
    mysql \
      -uroot \
      -P 3306 \
      -h `cat /tmp/mysql-ip` \
      -D $database \
      -e "
        use $database;
        UPDATE wp_options SET
          option_value = 'http://migrated.callowayart.com'
        WHERE
          option_name = 'home' OR
          option_name = 'siteurl'
      ";
  }
end