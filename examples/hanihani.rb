#!/usr/bin/ruby

$KCODE = 'u'

require 'tnok2ch'
require 'nkf'

# キャッシュの保存先
CACHE_DIR = File.join(File.dirname(__FILE__), 'cache')
TNOK2ch::CachedAgent.cache_dir = CACHE_DIR

# 板メニューを取得
ua_menu = TNOK2ch::GZippedAgent.new(URI.parse(TNOK2ch::BBSMenu::URL_BBSMENU))
if ua_menu.cache_exist? then
  # キャッシュがあるのでそれを使う。更新チェックはしない。
  printf("bbsmenu: cache already present\n")
  ua_menu.get_cache
else
  # キャッシュはないので取りにいく。
  printf("GET: %s\n", TNOK2ch::BBSMenu::URL_BBSMENU)
  ua_menu.start
end

bbsmenu = TNOK2ch::BBSMenu.new
# UA が取得したデータで板メニューを解析
bbsmenu.parse(NKF.nkf('--utf8', ua_menu.body))

# 東亜+ の板情報を取得
news4plus = bbsmenu["news4plus"].first

# 板情報を出しておく
printf("%s: %s\n", news4plus.title, news4plus.url)
printf("GET: %s\n", news4plus.subject_uri.to_s)

# スレッド一覧取得
ua_subject = TNOK2ch::GZippedAgent.new(news4plus.subject_uri)
ua_subject.start # キャッシュがあれば更新チェックののち使用、初回取得時は GZip

# 取得結果
printf("HTTP/%s %d %s, ", ua_subject.response.http_version,
       ua_subject.response.code, ua_subject.response.message)
printf("update: %s\n",
       ua_subject.last_modified.strftime("%Y-%m-%d %H:%M:%S"))

# UA が取得したデータで板情報を構築
news4plus.parse(NKF.nkf('--utf8', ua_subject.body))

# はにはにスレっぽいスレタイ
threads = news4plus[/(放火|腹立ち(まぎ|紛)れ)/].sort_by{|i| i.since }.reverse

# あぼーん対応 DAT 取得
def get_thread(uri)
  ua_dat = TNOK2ch::DatAgent.new(uri)
  thread = TNOK2ch::Thread.new
  
  printf("GET: %s\n", uri.to_s)
  ua_dat.start # キャッシュがあれば更新チェックののち新着のみ取得、初回取得時は GZip

  while true do
    # 取得結果
    printf("HTTP/%s %d %s, ", ua_dat.response.http_version,
           ua_dat.response.code, ua_dat.response.message)
    printf("update: %s\n", ua_dat.last_modified.strftime("%Y-%m-%d %H:%M:%S"))

    # body には >>1 からの全レスが入っている（新着取得をしたときはキャッシュと合成される）
    if ua_dat.body then
      # レス情報を構築
      thread.parse(NKF.nkf('--utf8', ua_dat.body))
      break
    else
      # あぼーん検出、キャッシュを破棄して再取得
      ua_dat.delete_cache
      printf("GET: %s\n", uri.to_s)
      ua_dat.start
    end
  end
  thread
end

threads.each{|thread|
  # スレキーとスレタイ
  printf("%10d: %s\n", thread.thread, thread.title)

  # DAT を取得してレス情報を構築
  thre = get_thread(thread.dat_uri)
  # >>1 だけ表示
  res = thre.replies.first
  printf("    %d: %s[%s] %s ID:%s\n", res[:number], res[:name], res[:email],
         res[:date].strftime("%Y-%m-%d %H:%M:%S"), res[:id])
  # DAT を行分割してそれっぽく表示
  res[:body].split(/<br>/).each{|line|
    printf("    %s\n", line.chomp)
  }
  print "\n\n"
}
