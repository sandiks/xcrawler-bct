require 'nokogiri'
require 'open-uri'
require 'parallel'
require_relative  '../helpers/helper'
require_relative  '../helpers/repo'
require_relative  '../helpers/page_utils'
require_relative  'bct_parser'


class BCTalkParserAdv
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20

  @@fid=0

  @@options={}

  #def self.check_selected_threads; BCTalkParserHelper.check_selected_threads; end
  def self.set_opt(opts={}); @@options = opts; return self; end
  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

  def self.load_list_forums_pages_threads_responses_to_stat_thread(forums,hours_back)

    #Parallel.map(forums,:in_threads=>3) do |fid|
    forums.each do |fid|
      if need_parse(fid)
        load_thread_responses_to_stat_thread(fid,hours_back)
      else
        p "already parsed #{fid}"
      end 
    end

  end

  def self.need_parse(fid)
    last_parsed = DB[:forums_stat].filter(sid:SID, fid:fid)
    .reverse_order(:bot_parsed).limit(1).select_map(:bot_parsed).first

    return true unless last_parsed 
    last_parsed.to_datetime<date_now(1/3.0)
  end

  def self.load_thread_responses_to_stat_thread(fid, hours=12, start_page=1) 
    
    BCTalkParser.set_opt({rank:4})
    BCTalkParser.class_variable_set(:@@from_date, date_now(hours))
    
    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    interval = "from #{BCTalkParser.from_date.strftime("%F %H:%M:%S")}- to #{date_now.strftime("%F %H:%M:%S")}"
    p "----------------FORUM: (#{fid}) #{title} #{interval}"


    last_page_date = date_now
    #BCTalkParser.from_date = date_now(hours)
    
    
    finish = false
    start_page.upto(start_page+40) do |pg|
        break if finish
        next if pg<1
        
        loop do
          begin
            last_page_date = BCTalkParser.parse_forum(fid,pg)
            finish=true  if last_page_date.nil? || last_page_date < BCTalkParser.from_date
            break
          rescue  =>ex 
            puts "#{fid} #{pg} #{ex} "
            sleep 5
          end
        end      
    end
    DB[:forums_stat].insert({sid:SID, fid:fid, bot_action:"load_thread_responses_to_stat_thread hours_back:#{hours}" , bot_parsed: date_now})

  end

  THREADS_ANALZ_NUM=15


  ## read from "stat_threads" table and download thread posts for last 3 pages 
  def self.load_threads_with_max_responses_for_last12h(fid, h_back =24)
    
    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    p "----------------FORUM:#{title}"

    BCTalkParser.class_variable_set(:@@from_date, date_now(h_back))
    from=date_now(h_back)

    p "load_forumPage_threads_from0_n3  fid:#{fid} h_back:#{h_back} start_from:#{from.strftime("%F %H:%M:%S")}"
    to=date_now(0)

    forum_threads = DB[:stat_threads].filter(Sequel.lit("sid=? and fid=? and last_post_date > ?", SID,fid,from))
    .select_map([:tid,:responses,:last_post_date])

    list_threads = []
    start_date = date_now(12)

    ########analz
    max_resps_threads = forum_threads.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    #max_resps_threads.each do |tid, tt|
    Parallel.map(max_resps_threads,:in_threads=>3) do |tid,tt|
      
      resps_minmax=tt.map { |el| el[1]  }.minmax

      page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
      lpage = page_and_num[0]
      lcount = page_and_num[1]
      
      downl_pages=BCTalkParser.calc_arr_downl_pages(tid,lpage,lcount, BCTalkParser.from_date).take(10)

      url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
      p url = url_templ % [tid,(lpage-1)*40]
      
      res=[]
      stars=0
      downl_pages.each do |pp| 
        res<<pp[0]
        begin
          data = BCTalkParser.parse_thread_page(tid, pp[0]) 
          stars += data[:stars]||0
        rescue =>ex
          p "--err tid #{tid} pg #{pp} --#{ex}"
        end
      end
      
      planned_str=downl_pages.map { |pp| "<#{pp[0]}*#{pp[1]}>" }.join(', ')
      
      p "[load_thr #{tid} last:#{page_and_num}".ljust(40)+
      "planned:#{planned_str.ljust(40)}  down:#{res} stars:#{stars}" if downl_pages.size>0     

    end

  end
end
    

fid = ARGV[1].to_i

case ARGV[0]
  when '1'; BCTalkParserAdv.load_thread_responses_to_stat_thread(fid,12)

  when '2'; BCTalkParserAdv.load_threads_with_max_responses_for_last12h(fid,12)
end