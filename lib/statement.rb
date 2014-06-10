class Statement

  class << self

    # execute statements/name 
    def query(name, params={ })
      name = name.to_s

      # create es client
      client = Elasticsearch::Client.new
      erb    = ERB.new(content = File.read(
        "#{ENV['RAILS_ROOT']}/db/elasticsearch/statements/" +
        "#{name}.json.erb"
      ))

      # parse and return valid statement and pass to 
      # elasticsearch client
      statement = erb.result OpenStruct.new(params).instance_eval { 
        binding 
      }
      result    = client.search index: 'callowayart', 
                                body:  statement

      # now massage result set into a simpler data structure
      data = [ ]

      # if aggregations have been returned, we are returning
      # a grouped result set
      if result['aggregations'].nil?
        result['hits']['hits'].each do | hash |
          bucket = hash['_source']
          record = {
            title: bucket['title'],
            description: bucket['description'],
            image: bucket['constrainedw'],
            thumb: bucket['thumb'],
            artist: bucket['artist'],
            thumbh: bucket['thumbh'],
            available: !bucket['tags'].include?( 'not-available' )
          }

          %w{ 
            artist_description exhibit exhibit_description artist_slug exhibit_slug

          }.each do | field |
            record[field.to_sym] = bucket[field] unless bucket[field].nil?
          end

          data << record
        end

      else
        result['aggregations'].first.pop['buckets'].each do | bucket |
          record = {
            title:  bucket['key'],
            count:  bucket['doc_count'],
            image:  bucket['uri']['buckets'][0]['key'],
            thumb:  bucket['thumb']['buckets'][0]['key'],
            artist: bucket['artist']['buckets'][0]['key'],
            description: bucket['key'],
            available: true
          }

          # do something with record here
          %w{ 
            artist_description 
            exhibit 
            exhibit_description 
            artist_slug 
            exhibit_slug
            exhibit_start

          }.each do | field |
            if bucket[field] && !bucket[field]['buckets'].empty? 
              record[field.to_sym] = bucket[field]['buckets'][0]['key']
            end
          end          

          # add record to queue
          data << record

        end
      end

      data
    end

    def method_missing(name, *arguments)
      query name, arguments.pop
    end

  end

end