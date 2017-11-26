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

  def self.need_parse(fid)
    last_parsed = DB[:forums_stat].filter(sid:SID, fid:fid)
    .reverse_order(:bot_parsed).limit(1).select_map(:bot_parsed).first

    return true unless last_parsed
    last_parsed.to_datetime<date_now(1/2.0)
  end

  def self.save_thread_responses_statistics_FOR_LIST_FORUMS(forums,hours_back)

    #Parallel.map(forums,:in_threads=>3) do |fid|
    forums.each do |fid|
      if need_parse(fid)
        save_thread_responses_statistics(fid,hours_back)
      else
        p "already parsed #{fid}"
      end
    end

  end

  def self.save_thread_responses_statistics(fid, hours=12, start_page=1)

    BCTalkParser.set_opt({rank:4})
    BCTalkParser.set_from_date(hours) #class_variable_set(:@@from_date, date_now(hours))

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    interval = "from #{BCTalkParser.from_date.strftime("%F %H:%M:%S")}- to #{date_now.strftime("%F %H:%M:%S")}"
    p "----------------FORUM: (#{fid}) #{forum_title} #{interval}"


    last_page_date = date_now
    #BCTalkParser.from_date = date_now(hours)


    finish = false
    start_page.upto(start_page+80) do |pg|
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

  THREADS_ANALZ_NUM=20
  ## read from "threads_stat" table and download thread posts for last 3 pages
  def self.load_posts_for_max_responses_threads_in_interval(fid, hours_back =24)

    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    p "----------------FORUM: #{fid} #{title}"

    from=date_now(hours_back)
    to=date_now(0)

    unreliable_threads = DB[:threads].filter(Sequel.lit("fid=? and reliable<0.3",fid)).select_map(:tid)

    p " --load_max_responses_threads_posts_in_interval fid:#{fid} hours_back:#{hours_back} start_from:#{from.strftime("%F %H:%M:%S")}"
    
    #threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ? ",fid, from))
    threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ? and tid not in ?",fid, from, unreliable_threads))
    .select_map([:tid,:responses,:last_post_date])

    ########analz
    sorted_thread_stats = threads_responses.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    #sorted_thread_stats.each do |tid, tt|
    Parallel.map_with_index(sorted_thread_stats,:in_threads=>1) do |rr,idx|

      tid = rr[0]
      resps = rr[1]
      #next if tid!=2398403
      #resps_minmax=resps.map { |el| el[1]  }.minmax ##resps_minmax[1]+1      

      saved_reliable = DB[:threads].first(fid:fid, tid:tid)[:reliable]
      if saved_reliable && saved_reliable<0.3
        p "--- reliable low #{saved_reliable} #{tid}"
        next
      end
      load_thread_before_date(fid, tid, hours_back)
    end
  end

  def self.load_only_top10_post_in_thread(tid, downl_rank=4) ## for site, show when you click 'post' button

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

  def self.load_unreliable_threads(fid) ## for site, show when you click 'post' button

      unreliable_threads = DB[:threads].filter(Sequel.lit("fid=? and reliable<0.3",fid)).select(:tid, :title).all
      unreliable_tids = unreliable_threads.map{|x| x[:tid]}
      unreliable_titles = unreliable_threads.map{|x| x[:title].gsub('?', '').strip }

      p unreliable_tids
      p "------------"

      unreliable_tids.each do |tid|
        load_thread_before_date(fid,tid,12)
      end

  end

  def self.load_thread_before_date(fid, tid, hours_back=12)

    from = date_now(hours_back)
    to=date_now(0)

    BCTalkParser.set_from_date(hours_back)

    responses =  DB[:threads].first(siteid:SID, tid:tid)[:responses]

    page_and_num = PageUtil.calc_last_page(responses+1,20)
    lpage = page_and_num[0]
    lcount = page_and_num[1]

    url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
    url = url_templ % [tid,(lpage-1)*40]

    downl_pages=BCTalkParser.calc_arr_downl_pages(tid, lpage, lcount, from).take(15)

    finished_downl_pages=[]
    ranks_stat_all=Hash.new(0)

    downl_pages.each do |pp|

      finished_downl_pages<<pp[0]
      begin
        data = BCTalkParser.set_opt({rank:1, parse_signature:false}).parse_thread_page(tid, pp[0])

        ranks_stat= data[:stat].group_by{|x| x}.map{|k,vv| [k,vv.size]}.to_h
        [1,2,3,4,5,11].each{|x| ranks_stat_all[x]+= (ranks_stat[x]||0)}

        fpdate = data[:first_post_date]
        break if  fpdate<from

      rescue =>ex
        #puts ex.backtrace
        p "--err tid #{tid} pg #{pp} --#{ex}"
      end
    end

    downloaded_pages_str = finished_downl_pages #downl_pages.map { |pp| "#{pp[0]}_#{pp[1]}" }.join(' ')

    if  ranks_stat_all

      rr={
        fid:fid, tid:tid, description:"downloaded_pages #{downloaded_pages_str}" ,
        start_date:from, end_date:to, added: date_now, last_page:lpage,
        r1_count:ranks_stat_all[1],r2_count:ranks_stat_all[2],
        r3_count:ranks_stat_all[3],r4_count:ranks_stat_all[4],
        r5_count:ranks_stat_all[5],r11_count:ranks_stat_all[11],
      }
      DB[:threads_stat].insert(rr)

      dd=[rr[:r1_count],rr[:r2_count],rr[:r3_count],rr[:r4_count],rr[:r5_count],rr[:r11_count]]
      sum = dd.sum
      reliable = 1- (dd[0]+dd[1])/sum.to_f     
      #DB[:threads].filter(siteid:9, tid: tid).update(reliable: reliable) if  sum>20

    end

    planned_str=downl_pages.map { |pp| "#{pp[0]}" }.join(' ')
    
    p "---load_thr #{tid} last pg,count: #{page_and_num}".ljust(50)+
    "planned:#{planned_str.ljust(30)}  down:#{finished_downl_pages} ranks_stat_all: #{dd}" if downl_pages.size>0     

  end

  def self.calc_reliable_for_forum(fid, time =24)

    from=date_now(time)
    to=date_now(0)

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable])

    ## unreliable threads
    unreliable_threads = threads_attr.select{ |k,v| v[1] && v[1]<0.3   }
    unreliable_tids = unreliable_threads.keys
    unreliable_titles = unreliable_threads.map{|tid,v| "tid:#{tid} #{v[0].gsub('?', '').strip}" }

    threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ? and tid not in ?", fid, from, unreliable_tids))
    .select_map([:tid,:responses,:last_post_date])


    max_resps_threads = threads_responses.group_by{|h| h[0]}
    .select{ |k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(40)

    indx=0
    out = []

    max_resps_threads.each do |tid, tt|

      indx+=1
      min_date_from_thread_stat = tt.min_by{|x| x[2]}[2]

      ## calc reliable
      ranks = DB[:posts].filter( Sequel.lit("tid=? and addeddate > ?", tid, min_date_from_thread_stat) )
      .order(:addeddate).select_map(:addedrank)
      

      ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
      sum = ranks_gr.map{ |dd| dd[1] }.sum
      next if sum==0
      
      reliable_ff = 1-( (ranks_gr[1]||0) + (ranks_gr[2]||0) )/sum.to_f 
      
      if sum>30 && reliable_ff<0.3
        thr_title_cleaned = threads_attr[tid][0].gsub('?', '').strip ####.gsub(/\A[\d_\W]+|[\d_\W]+\Z/, '')
        out<<"#{indx} ff: #{reliable_ff} ranks #{ranks_gr}  [b]#{thr_title_cleaned}[/b]"
        DB[:threads].filter(siteid:9, tid: tid).update(reliable: reliable_ff)

      end

    end
    out<<"------------"


    if true #show_unreliable_threads
      out<< "[color=red]UNRELIABLE THREADS!!![/color]"
      out+= unreliable_titles
      out<<"------------"
    end    

    @@report_file = "calc_reliable_#{fid}.txt"
    File.write("report/"+@@report_file, out.join("\n"))

  end
##end of class
end
    
