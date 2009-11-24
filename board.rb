
require 'uri'
require 'subject.rb'

module TNOK2ch
  class Board
    RE_SUBJECT_ENTRY = /^(\d+)\.dat<>(.*?) \((\d+)\)$/i

    attr_reader :url
    attr_reader :host
    attr_reader :name
    attr_reader :title
    attr_reader :base_uri

    attr_reader :subjects

    # _uri_:: URI
    # _title_:: String
    def initialize(uri, title, body = nil)
      @title = title
      @name = uri.path.gsub(/\//,'')
      @url = uri.to_s
      @host = uri.host
      @base_uri = URI.join("http://#{@host}", "/#{@name}")
      @subjects = nil

      parse(body) if body
    end

    def subject_uri
      URI.parse(@base_uri.to_s + "/subject.txt")
    end
    
    def parse(body)
      @subjects = []

      body.each_line do |line|
        if RE_SUBJECT_ENTRY =~ line then
          thread, title, replies = $1, $2, $3
          @subjects << Subject.new(@base_uri, thread, title, replies)
        end
      end
      @subjects
    end

    def [](v, find_what = :title)
      @subjects.select{|i| v === i.send(find_what) }
    end
    
    def sort_by(key)
      @subjects.sort_by{|i| i.send(key) }
    end
  end
end
