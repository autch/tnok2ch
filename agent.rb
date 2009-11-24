
require 'uri'
require 'time'
require 'net/http'
require 'stringio'
require 'zlib'
require 'fileutils'
require 'digest/md5'

module TNOK2ch
  class CachedAgent
    USER_AGENT = "Monazilla/1.00 (tnok2ch.rb/1.00)"
    DEFAULT_HEADERS = { 'User-Agent' => USER_AGENT }

    attr_reader :request
    attr_reader :response
    attr_reader :uri
    attr_reader :body
    attr_reader :filename
    attr_reader :last_modified

    @@cache_dir = "."

    def self.cache_dir
      @@cache_dir
    end

    def self.cache_dir=(v)
      @@cache_dir = v
    end

    def initialize(uri, prefix = '', cache_dir = nil)
      @cache_dir = cache_dir || @@cache_dir
      @uri = uri
      @request = Net::HTTP::Get.new(@uri.request_uri, DEFAULT_HEADERS)
      @response = nil
      @body = nil
      @filename = File.join(@cache_dir,
                            "%s%s.cache" %
                            [prefix, Digest::MD5.hexdigest(@uri.to_s)])
      @last_modified = nil
    end

    def start()
      Net::HTTP.start(@uri.host, @uri.port) do |http|
        if cache_exist? then
          @request['If-Modified-Since'] = File.mtime(@filename).httpdate
        end
        http.request(@request){|response|
          @response = handle_response(response)
        }
      end
    end

    def get_cache
      @body || (@body = File.read(@filename))
    end

    def delete_cache
      FileUtils.rm(@filename, { :force => true })
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess then
        @body = response.body
        @last_modified = lm_time(response)
        File.open(@filename, "wb"){|f|
          f.write(@body)
        }
        File.utime(@last_modified, @last_modified, @filename)
      when Net::HTTPNotModified then
        @body = File.read(@filename)
        @last_modified = File.mtime(@filename)
      end
      response
    end

    def cache_exist?
      File.exist?(@filename)
    end

    private

    def lm_time(res)
      Time.httpdate(res['Last-Modified']) rescue Time.now
    end
  end

  class GZippedAgent < CachedAgent
    def initialize(uri, prefix = '', cache_dir = nil)
      super
      @request['Accept-Encoding'] = 'gzip'
    end

    def get_cache
      Zlib::GzipReader.open(@filename){|gz|
        @body = gz.read
      }
    end

    def handle_response(response)
      super
      case response
      when Net::HTTPSuccess then
        if response['Content-Encoding'] == 'gzip' then
          get_cache
        end
      when Net::HTTPNotModified then
        get_cache
      end
      response
    end
  end

  # use only for DATs
  class DatAgent < CachedAgent
    def start()
      Net::HTTP.start(@uri.host, @uri.port) do |http|
        if cache_exist? then
          @request['If-Modified-Since'] = File.mtime(@filename).httpdate
          @request['Range'] = sprintf("bytes= %d-", File.size(@filename) - 1)
        else
          @request['Accept-Encoding'] = 'gzip'
        end
        http.request(@request){|response|
          @response = handle_response(response)
        }
      end
    end

    def handle_response(response)
      case response
      when Net::HTTPOK then
        @last_modified = lm_time(response)
        if response['content-encoding'] == 'gzip' then
          # decode gzip
          body = response.body
          sio = StringIO.new(body)
          sio.rewind
          Zlib::GzipReader.wrap(sio){|gz|
            @body = gz.read
          }
        else
          @body = response.body
        end
        # save to file
        File.open(@filename, "wb"){|file|
          file.write(@body)
        }
        File.utime(@last_modified, @last_modified, @filename)
        get_cache
      when Net::HTTPNotModified then
        # not modified, just return cache
        @last_modified = File.mtime(@filename)
        get_cache
      when Net::HTTPPartialContent then
        # unread
        @last_modified = lm_time(response)
        body_part = response.body
        if /^\n/ =~ body_part then
          # just new
          File.open(@filename, "ab"){|file|
            file.write(body_part.gsub(/^\n/, ''))
          }
          File.utime(@last_modified, @last_modified, @filename)
          get_cache
        else
          # there's some abone
          @body = nil
        end
      when Net::HTTPRequestedRangeNotSatisfiable then
        # unread + abone
        @last_modified = lm_time(response)
        @body = nil
      end
      response
    end
  end
end
