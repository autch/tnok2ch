#!/usr/bin/ruby

$KCODE = 'u'

require 'nkf'
require 'tnok2ch.rb'

CACHE_DIR = File.join(File.dirname(__FILE__), 'cache')
TNOK2ch::CachedAgent.cache_dir = CACHE_DIR

url = ARGV.shift

unless url then
  puts "Usage: get_dat.rb http://server.2ch.net/board/dat/0000000000.dat"
  exit -1
end

ua_dat = TNOK2ch::DatAgent.new(URI.parse(url))
printf("GET: %s\n", url)
ua_dat.start

thread = TNOK2ch::Thread.new

while true do
  printf("HTTP/%s %d %s, ", ua_dat.response.http_version,
         ua_dat.response.code, ua_dat.response.message)
  printf("update: %s\n",
         ua_dat.last_modified.strftime("%Y-%m-%d %H:%M:%S"))

  if ua_dat.body then
    # got some replies
    printf("Got it\n")
    thread.parse(NKF.nkf('--utf8', ua_dat.body))
    break
  else
    # abone happened
    printf("ABONE happened, deleting cache then retry\n")
    ua_dat.delete_cache
    ua_dat.start
  end
end

thread.replies.each{|res|
  printf("%d: %s[%s] %s ID:%s\n", res[:number], res[:name], res[:email],
         res[:date].strftime("%Y-%m-%d %H:%M:%S"), res[:id])
}

