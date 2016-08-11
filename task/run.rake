#!/usr/bin/env ruby
# callowaylc@gmail.com
# Provides interface to running application and dependecies

namespace :run do

  desc "build application and run"
  task application: %i{ mysql php nginx } do
    command  %{
      export MYSQL_PWD=mysecretpassword
      export path=/docker/shared/application/callowayart.com
      database=devbrand_wdp-103964
      (
        sudo rm -rf $path/*
        sudo mkdir -p $path
        sudo chmod -R a+rwx $path
      ) > /dev/null 2>&1

      # expand application
      aws s3 cp s3://callowayart/artifacts/wp-brandefined.tgz /tmp/wp.tgz
      sudo tar -xvzf /tmp/wp.tgz -C $path > /dev/null 2>&1
      cp -rf ./application/callowayart.com `dirname $path`

      # make sure uploads directory is world writable
      sudo chmod -R 777 $path/wp-content/uploads
      mkdir -p $path/wp-content/uploads/shared

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
      sudo tar -xvzf /tmp/wordpress-callowayart.sql.tgz -C /tmp/wordpress-callowayart.sql > /dev/null 2>&1

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
      # run migration
      #TBD
    }
  end

  desc "run mysql container"
  task :mysql do
    command  %{
      name=mysql
      image=$name:5.7.13
      (
        sudo docker pull $image
        sudo docker rm -f $name-0
      ) > /dev/null 2>&1

      sudo docker run \
        -d \
        --name $name-0 \
        --volume /docker/mysql-0/data:/var/lib/mysql:rw \
        --env MYSQL_ROOT_PASSWORD=mysecretpassword \
          $image

      # write docker ip to /tmp executable
      sudo docker inspect mysql-0 |
        grep -i ipaddr |
        tail -n -1 |
        awk '{print $2}' |
        sed -r 's/[^0-9.]+//g' \
          > /tmp/mysql-ip

      # wait until available
      ~/bin/block-until-response `cat /tmp/mysql-ip` 3306 10
    }
  end

  desc "run redis container"
  task :redis do
    command %{
      image='redis:3.0.7'
      path=/usr/local/etc/redis/redis.conf

      (
        sudo docker pull $image
        sudo docker rm -f redis-0
        rake config:decrypt
      ) > /dev/null 2>&1

      # get password from config; parse config yaml into
      # key=value expressions which will place password into
      # current context. Next we eval redis.conf file, interpolate
      # password and write to docker path
      eval `sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' \
        ./config.yml | tail -n +2`
      config=$(
        eval "echo \"`cat ./usr/local/etc/redis/redis.conf | sed -e '/^#/d'`\""
      )

      # move redis.conf to docker mounted directory
      sudo mkdir -p /docker/redis-0/`dirname $path`
      echo "$config" > /docker/redis-0/$path

      sudo docker run \
        -d \
        --name=redis-0 \
        --volume="/docker/redis-0/$path:$path" \
        --publish="0.0.0.0:9736:6379" \
          $image redis-server $path
    }
  end

  desc "run php container"
  task :php do
    command  %{
      name=php
      image=$name:5.6-fpm
      (
        sudo docker pull $image
        sudo docker rm -f $name-0
        sudo rm -rf /docker/$name*
        sudo mkdir -p /docker/$name-0
        sudo chmod -R g+w /docker/$name-0
      ) > /dev/null 2>&1

      mkdir -p /docker/php-0/usr/local/etc/php
      cp -rf ./usr/local/etc/php /docker/php-0/usr/local/etc

      sudo docker run \
        -d \
        --name $name-0 \
        --volume /docker/$name-0/usr/local/etc/php/php.ini:/usr/local/etc/php/php.ini \
        --volume /docker/shared/application/callowayart.com:/application:rw \
        --volume /docker/$name-0/var/log/php:/var/log/php/error.log:rw \
        --link mysql-0:mysql-0 \
        --publish 0.0.0.0:9000:9000 \
          $image

      #for extension in "${extensions[@]}"; do
      #  sudo docker exec php-0 bash -c "docker-php-ext-install $extension"
      #done

      sudo docker exec php-0 bash -c "docker-php-ext-install gd"
      sudo docker exec php-0 bash -c "docker-php-ext-install mysql"
      sudo docker exec php-0 bash -c "docker-php-ext-install mysqli"
      sudo docker exec php-0 bash -c "docker-php-ext-install pdo_mysql"

      sudo docker restart php-0
    }
  end

  task :nginx do
    command  %{
      name=nginx
      image=$name:1.11.1
      path=/etc/nginx
      (
        sudo docker pull $image
        sudo docker rm -f $name-0
        rm -rf /docker/$name-0
        mkdir -p /docker/$name-0/$path
        sudo chmod -R g+w /docker/$name-0
      ) > /dev/null 2>&1

      cp -rf ./$path/conf.d /docker/$name-0/$path

      sudo docker run \
        -d \
        --name $name-0 \
        --publish 0.0.0.0:80:80 \
        --volume /docker/$name-0/etc/nginx/conf.d:/etc/nginx/conf.d \
        --volume /docker/shared/application/callowayart.com:/application:rw \
        --volume /docker/$name-0/var/log/nginx:/var/log/nginx:rw \
        --link php-0:php-0 \
        --env MYSQL_ROOT_PASSWORD=myscretpassword \
          $image
    }
  end
end