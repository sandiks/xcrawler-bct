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
    last_parsed.to_datetime<date_now(1/2.0)
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


  ## read from "threads_stat" table and download thread posts for last 3 pages 
  def self.load_thread_posts_with_max_responses_in_interval(fid, h_back =24)
    
    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    p "----------------FORUM: #{fid} #{title}"

    from=date_now(h_back)
    BCTalkParser.class_variable_set(:@@from_date, from)

    p "load_forumPage_threads_from0_n3  fid:#{fid} h_back:#{h_back} start_from:#{from.strftime("%F %H:%M:%S")}"
    to=date_now(0)

    thread_stats = DB[:threads_stat].filter(Sequel.lit("sid=? and fid=? and last_post_date > ?", SID,fid,from))
    .select_map([:tid,:responses,:last_post_date])

    list_threads = []
    start_date = date_now(12)

    ########analz
    sorted_thread_stats = thread_stats.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    #sorted_thread_stats.each do |tid, tt|
    Parallel.map_with_index(sorted_thread_stats,:in_threads=>1) do |rr,idx|
      
      tid = rr[0]
      resps = rr[1]

      resps_minmax=resps.map { |el| el[1]  }.minmax

      page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
      lpage = page_and_num[0]
      lcount = page_and_num[1]

      url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
      url = url_templ % [tid,(lpage-1)*40]
      
      downl_pages=BCTalkParser.calc_arr_downl_pages(tid,lpage,lcount, BCTalkParser.from_date).take(10)
      #p "[#{idx}] tid #{tid} downl_pages: #{downl_pages}"
      
      res=[]
      stars=0
      downl_pages.each do |pp| 
        res<<pp[0]
        begin
          data = BCTalkParser.set_opt({rank:1}).parse_thread_page(tid, pp[0]) 
          stars += data[:stars]||0
          fpdate = data[:first_post_date]
          #p "[#{idx}] tid pg [#{tid} #{pp[0]}] stars:#{stars} first date:#{fpdate.strftime("%F %H:%M:%S")}"
          break if  fpdate<from

        rescue =>ex
          p "--err tid #{tid} pg #{pp} --#{ex}"
        end
      end
      
      planned_str=downl_pages.map { |pp| "<#{pp[0]}*#{pp[1]}>" }.join(', ')
      
      p "[[#{idx}] load_thr #{tid} last pg,count: #{page_and_num}".ljust(55)+
      "planned:#{planned_str.ljust(40)}  down:#{res} stars:#{stars}" if downl_pages.size>0     

    end

  end

  def self.load_only_top10_post_in_thread(tid, downl_rank=4)

      responses= DB[:threads].filter(siteid:SID, tid: tid).select_map(:responses).first
      tpages = DB[:tpages].filter(Sequel.lit("siteid=? and tid=?", SID, tid)).to_hash(:page,:postcount)

      page_and_num = PageUtil.calc_last_page(responses+1,20)
      lpage = page_and_num[0]
      lcount = page_and_num[1]

      list_page_num= [[lpage,lcount]]
      list_page_num<<[lpage-1,20] if lcount<5 
    
      ##donwload pages
      list_page_num.each do |page_num, size|
        if tpages[page_num].nil? || tpages[page_num]<size
          p "---load page tid pg [#{tid} #{page_num}]"
          BCTalkParser.set_opt({rank:downl_rank}).parse_thread_page(tid, page_num)
        else
          p "---exist page tid pg [#{tid} #{page_num}] resps: #{responses}"
        end 

      end

  end

end
    