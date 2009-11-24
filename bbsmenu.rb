
require 'uri'
require 'board.rb'

module TNOK2ch
  class BBSMenu
    RE_BOARD_CATEGORY = /^<br><br><b>(.*?)<\/b><br>$/i
    RE_BOARD_ENTRY = /^<a href=([^ >]+)[^>]*>(.*?)<\/a>(<br>)?$/i

    URL_BBSMENU = 'http://menu.2ch.net/bbsmenu.html'

    attr_reader :categories

    def initialize(body = nil)
      @categories = []
      parse(body) if body
    end

    # _body_:: instance of String or IO
    def parse(body)
      @categories = []
      boards = []
      category = nil

      body.each_line do |line|
        case line
        when RE_BOARD_CATEGORY
          @categories << [category, boards] if category && !boards.empty?
          category = $1
          boards = []
        when RE_BOARD_ENTRY
          uri = URI.parse($1)
          caption = $2
          name = uri.path.gsub(/\//,'')
          next if name.empty?
          boards << Board.new(uri, caption)
        end
      end
      @categories << [category, boards] if category && !boards.empty?
      @categories
    end

    # _name_:: keyword to find, expressed in String or Regexp
    # _find_what_:: Symbol: key to find, one of: :url, :host, :name
    #               (default), :caption
    def [](name, find_what = :name)
      @categories.map{|i| i[1].select{|j| name === j.send(find_what) } }.flatten
    end    
  end
end
