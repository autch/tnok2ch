
require 'uri'
require 'time'

module TNOK2ch
  class Thread
    # name, email, date/id/be, body, title
    RE_RESPONSE_ENTRY = /^(.*?)<>(.*?)<>(.*?)<>(.*?)<>(.*?)$/i

    attr_reader :replies

    def initialize(body = nil)
      @replies = []
      parse(body) if body
    end

    def parse(body)
      @replies = []
      number = 1
      body.each_line do |line|
        if RE_RESPONSE_ENTRY =~ line then
          name, email, date_id_be, body, title = $1, $2, $3, $4, $5

          date = date_id_be
          if / ID:/ =~ date_id_be then
            _, date, id = */^(.*?) ID:([^ ]+)/.match(date_id_be)
          end
          if / BE:/ =~ date_id_be then
            _, be = */ BE:([^ ]+)/.match(date_id_be)
          end
          date.gsub!(/  .*$/, '')

          @replies << { :number => number, :name => name, :email => email,
            :date => Time.parse(date),
            :id => id, :be => be, :body => body, :title => title }

          number += 1
        end
      end
      @replies
    end

    def [](v, find_what = :body)
      @replies.select{|i| v === i[find_what] }
    end
  end
end
