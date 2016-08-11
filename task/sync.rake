#!/usr/bin/env ruby
# callowaylc@gmail.com
# Provides fswatch/rsync combination to provide seamless sync to
# remote environment

desc "sync to remote environment"
task :sync, [ :remote ] do | t, arguments |
  command  %{
    key=$( basename `pwd` )
    brew install fswatch > /dev/null 2>&1
    remote=#{ arguments[:remote] || 'pme-master' }

    function fsync {
      fswatch -0 $1 $key | xargs -0 -n1 -I {} \
        rsync \
          -azv \
          -e "ssh -o StrictHostKeyChecking=no" \
          --no-perms \
          --no-owner \
          --no-group \
          --exclude=.git \
          --exclude=pids \
          --exclude=logs \
          --omit-dir-times \
          --delete \
            $1/ $2
    }

    # kill any previous fsync processes attached to this sync
    pkill -9 -f $key

    # below isnt working in rake context.. falling back
    # to ruby solution
    path=`pwd`
    repository=${path/$HOME/'~'}

    fsync ./ $remote:$repository $key \
      > /tmp/sync.`basename $repository`.log 2>&1 &

    touch ./
  }
end