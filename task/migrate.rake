#!/usr/bin/env ruby
# callowaylc@gmail.com
# Migrates old callowayart to new database

desc "migrate to new callowayart"
task :migrate do
  #reset_database

  # get all works
  listings = [ ]
  posts    = query 'wordpress_callowayart', %{
    SELECT
      ID as id,
      post_content as content,
      post_title as title,
      guid as uri
    FROM wp_posts wp
    WHERE
      wp.post_type   = "attachment" AND
      wp.post_status = "inherit"
    ORDER BY wp.post_modified DESC
  }

  posts.each do | listing |

    begin
      open listing['uri']

    rescue
      meta = query 'wordpress_callowayart', %{
        SELECT
          meta_value
        FROM
          wp_postmeta
        WHERE
          meta_key = 'amazonS3_info' AND
          post_id = #{ listing['id'] }
      }

      unless meta.empty?
        listing['uri'] = 'http://callowayart-com.s3.amazonaws.com/' +
          meta[0]['meta_value'].match(
            /(?<resource>wp-content.+)\"/
          )[:resource]
      end
    end


    listings << memo('/listing', listing['id']) do
      # get artist iterating through terms
      ( query 'wordpress_callowayart', %{
        SELECT
          wpt.term_id as id,
          wpt.slug,
          wptt.parent as parent_id
        FROM wp_terms wpt
          INNER JOIN wp_term_taxonomy wptt
            ON wpt.term_id = wptt.term_id
          INNER JOIN wp_term_relationships wptr
            ON ( wptr.term_taxonomy_id = wptt.term_taxonomy_id )
        WHERE
          wptr.object_id = #{ listing['id'] }

      } ).each do | term |
        ( query 'wordpress_callowayart', %{
          SELECT
            description
          FROM wp_term_taxonomy wptt
            INNER JOIN wp_terms wpt
              ON ( wpt.term_id = wptt.parent )
          WHERE
            wptt.term_id = #{ term['id'] } AND
            wpt.slug = 'artist'
        } ).each do | tax |
          listing['artists'] ||= [ ]
          listing['artists'] << {
            'slug' => term['slug'],
            'description' => tax['description']
          }
        end

        ( query 'wordpress_callowayart', %{
          SELECT
            description
          FROM wp_term_taxonomy wptt
            INNER JOIN wp_terms wpt
              ON ( wpt.term_id = wptt.parent )
          WHERE
            wptt.term_id = #{ term['id'] } AND
            wpt.slug = 'exhibit'
        } ).each do | tax |
          # add artist to something..
          listing['exhibits'] ||= [ ]
          listing['exhibits'] << {
            'slug' => term['slug'],
            'description' => term['description']
          }
        end
      end

      {
        /\$/ => 'price',
        /(oil|pain|canvas|mono|paper|mixed|media|acrylic)/i => 'media',
        /(x|')/ => 'size'

      }.each do | expression, type |
        ( listing['content'].split /[\r\n]+/ ).last( 4 ).each do | line |
          if expression =~ line
            listing[type] = ( line.gsub /^.+\:/, '' ).sub /\$/, ''
            break
          end
        end
      end

      listing
    end
  end

  artists( listings ).each do | slug, artist |
    artist = insert_artist artist

    artist['listings'].each do | listing |
      listing = insert_work artist, listing
    end
  end

end


# methods #######################################

private def query database, sql
  @database ||= { }
  @database[database] ||= begin
    Mysql2::Client.new(
      host: `cat /tmp/mysql-ip`,
      user: 'root',
      password: 'mysecretpassword',
      database: database
    )
  end

  begin
    ( @database[database].query sql ).each
  rescue => _
    [ ]
  end
end

private def artists listings
  artists = { }

  listings.each do | listing |
    if listing['artists']
      listing['artists'].each do | artist |
        slug = artist['slug']
        artists[slug] ||= {
          'description' => artist['description'],
          'slug' => slug,
          'listings' => [ ],
          'exhibits' => [ ]
        }
        artists[slug]['listings'] << listing

        if listing['exhibits']
          listing['exhibits'].each do | exhibit |
            artists[slug]['exhibits'] << exhibit
          end
        end
      end
    end
  end

  artists
end

private def insert_work artist, listing
  # insert thumbnail post
  query 'devbrand_wdp-103964', %{
    INSERT INTO
      wp_posts(
        post_author,
        post_date,
        post_date_gmt,
        post_modified,
        post_modified_gmt,
        post_excerpt,
        to_ping,
        pinged,
        post_content_filtered,
        post_content,
        post_title,
        post_password,
        post_name,
        guid,
        post_type,
        post_mime_type

      ) values (
        1,
        now(),
        now(),
        now(),
        now(),
        '',
        '',
        '',
        '',
        '',
        "#{ File.basename listing['uri'], '.*' }",
        "",
        "#{ File.basename listing['uri'], '.*' }",
        "#{ listing['uri']  }",
        "attachment",
        "image/jpeg"
      )
  }

  thumbnail = (
    query "devbrand_wdp-103964", "select last_insert_id() as id"
  )[0]

  {
    _wp_attached_file: "shared/#{ listing['id'] }.jpg"

  }.each do | field, value |
    query "devbrand_wdp-103964", %{
      INSERT INTO wp_postmeta (
        post_id, meta_key, meta_value
      ) values (
        #{ thumbnail['id'] }, '#{ field }', '#{ value }'
      )
    }
  end

  # write to shared directory
  path = "/docker/shared/application/callowayart.com/wp-content/uploads/shared"
  File.write "#{ path }/#{ listing['id'] }.jpg", ( open listing['uri'] ).read


  # insert descriptive post
  query 'devbrand_wdp-103964', %{
    INSERT INTO
      wp_posts(
        post_author,
        post_date,
        post_date_gmt,
        post_modified,
        post_modified_gmt,
        post_excerpt,
        to_ping,
        pinged,
        post_content_filtered,
        post_content,
        post_title,
        post_password,
        post_name,
        guid,
        post_type

      ) values (
        1,
        now(),
        now(),
        now(),
        now(),
        '',
        '',
        '',
        '',
        '',
        "#{ listing['title'] }",
        "",
        "#{ listing['title'].slugify }",
        "#{ listing['title'].slugify }",
        "works"
      )
  }

  listing['id'] = (
    query "devbrand_wdp-103964", "select last_insert_id() as last_insert_id"
  )[0]['last_insert_id']

  {
    _thumbnail_id: thumbnail['id'],
    _edit_last: 1,
    _edit_lock: '1470885356:3',
    :'works-artist' => artist['id'],
    :'_works-artist' => 'field_56deeff321416',
    :'works-media-type' => listing['media'],
    :'_works-media-type' => 'field_56def0e021417',
    :'works-price' => listing['price'],
    :'_works-price' => 'field_56def14d21418',
    :'works-size' => listing['size'],
    :'_works-size' => 'field_56df2554708e5',
    :'eg-artist' => deslug( artist['slug'] )

  }.each do | field, value |
    query "devbrand_wdp-103964", %{
      INSERT INTO wp_postmeta (
        post_id, meta_key, meta_value
      ) values (
        #{ listing['id'] }, '#{ field }', '#{ value }'
      )
    }
  end

  listing
end

private def insert_artist artist
  query 'devbrand_wdp-103964', %{
    INSERT INTO
      wp_posts(
        post_author,
        post_date,
        post_date_gmt,
        post_modified,
        post_modified_gmt,
        post_excerpt,
        to_ping,
        pinged,
        post_content_filtered,
        post_content,
        post_title,
        post_password,
        post_name,
        guid,
        post_type

      ) values (
        1,
        now(),
        now(),
        now(),
        now(),
        '',
        '',
        '',
        '',
        '[et_pb_section admin_label="section"]
         [et_pb_row admin_label="row"]
         [et_pb_column type="4_4"]
         [et_pb_text admin_label="Text"]
          #{ artist['description'] }
         [/et_pb_text][/et_pb_column][/et_pb_row][/et_pb_section]',
        "#{ deslug artist['slug'] }",
        "",
        "#{ artist['slug'] }",
        "#{ artist['slug'] }",
        "artist"
      )
  }

  artist['id'] = (
    query "devbrand_wdp-103964", "select last_insert_id() as last_insert_id"
  )[0]['last_insert_id']

  {
    _edit_last: 1,
    _edit_lock: '1470716055:3',
    _thumbnail_id: 279,
    eg_sources_html5_mp4: nil,
    eg_sources_html5_ogv: nil,
    eg_sources_html5_webm: nil,
    eg_sources_youtube: nil,
    eg_sources_vimeo: nil,
    eg_sources_wistia: nil,
    eg_sources_image: nil,
    eg_sources_iframe: nil,
    eg_sources_soundcloud: nil,
    eg_vimeo_ratio: 0,
    eg_youtube_ratio: 0,
    eg_wistia_ratio: 0,
    eg_html5_ratio: 0,
    eg_soundcloud_ratio: 0,
    eg_settings_custom_meta_skin: nil,
    eg_settings_custom_meta_element: nil,
    eg_settings_custom_meta_setting: nil,
    eg_settings_custom_meta_style: nil,
    _et_pb_post_hide_nav: 'default',
    _et_pb_page_layout: 'et_full_width_page',
    _et_pb_side_nav: 'off',
    _et_pb_use_builder: 'on',
    _et_pb_old_content: "
      <div class=\"side-description\">#{ artist['description'] }</div>
    "

  }.each do | field, value |
    query "devbrand_wdp-103964", %{
      INSERT INTO wp_postmeta (
        post_id, meta_key, meta_value
      ) values (
        #{ artist['id'] }, '#{ field }', '#{ value }'
      )
    }
  end

  artist
end

private def deslug slug
  ( slug.gsub /-/, ' ').split.map(&:capitalize).join(' ')
end
