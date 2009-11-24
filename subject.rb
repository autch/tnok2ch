
require 'uri'

module TNOK2ch
  class Subject
    attr_reader :thread
    attr_reader :title
    attr_reader :replies
    attr_reader :since

    def initialize(base_uri, thread, title, replies)
      @base_uri = base_uri
      @title = title
      @replies = replies.to_i
      @thread = thread.to_i
      @since = (thread =~ /^924\d{7}/) ? Time.now : Time.at(@thread)
    end

    def dat_uri
      URI.parse(@base_uri.to_s + "/dat/#{@thread.to_s}.dat")
    end

    def uri
      URI.parse(@base_uri.to_s + "/test/read.cgi/#{@thread.to_s}/")
    end
  end
end
