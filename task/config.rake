#!/usr/bin/env ruby
# callowaylc@gmail.com
# Provides rsa key-file symmetric encryption of secrets

namespace :config do

  task :keys do
    # creates symmetric keys required for encryption/decryption
    # of secrets; do not execute this task once keys have been
    # distrubted
    exec %{
      name=contact-email-crawler
      rm -rf /tmp/$name
      (
        ssh-keygen \
          -f  /tmp/$name \
          -t rsa -N '' && \
        openssl rsa \
          -in /tmp/$name \
          -outform PEM \
          -pubout \
          -out ~/.ssh/$name.public.pem && \
        openssl rsa \
          -in /tmp/$name \
          -outform PEM \
          -out ~/.ssh/$name.private.pem
      ) > /dev/null 2>&1
      ls -lhat ~/.ssh/$name*
    }
  end

  desc "encrypt config"
  task :encrypt do
    exec %{
      name=contact-email-crawler
      rm ./.config.yml
      openssl rand -base64 128 -out ./key

      # encrypt config file and write to ./.config.yml
      cat ./config.yml | openssl \
        enc \
        -aes-256-cbc \
        -salt \
        -pass file:./key > ./.config.yml

      # encrypt key file rsa key
      cat ./key | openssl \
        rsautl \
        -encrypt \
        -inkey ~/.ssh/$name.public.pem \
        -pubin > ./key.encrypted

      rm ./key
    }
  end

  desc "decrypt config"
  task :decrypt do
    exec %{
      name=contact-email-crawler
      rm -rf ./config.yml

      # decrypt key file
      cat ./key.encrypted | openssl \
        rsautl \
        -decrypt \
        -inkey ~/.ssh/$name.private.pem \
          > ./key

      # decrypt the secrets
      cat ./.config.yml | openssl \
            enc \
            -d \
            -aes-256-cbc \
            -pass file:./key > ./config.yml

      rm ./key
    }
  end
end
