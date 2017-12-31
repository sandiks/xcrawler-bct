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
    last_parsed.to_datetime<date_now(0.2)
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
    parsed_dates = DB[:forums_stat].filter(fid:fid).all.map { |dd| dd[:bot_parsed].strftime("%F %H:%M:%S") }
    
    p "----------------FORUM: (#{fid}) #{forum_title} hours_back:#{hours}"
    p "--- last parsed : #{parsed_dates.last(4)}"


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

  def self.calc_tid_list_for__report_response_statistic(fid, hours_back =24)

    from=date_now(hours_back)
    threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ?",fid, from)).select_map([:tid,:responses,:last_post_date])

    sorted_thread_stats = threads_responses.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax;  dd.last-dd.first }
    .reverse.take(THREADS_ANALZ_NUM)

  end

  def self.load_posts_for_max_responses_threads_in_interval(fid, hours_back =24)

    from=date_now(hours_back)
    to=date_now(0)

    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    p "----------------FORUM: #{fid} #{title}"

    parsed_dates = DB[:forums_stat].filter(Sequel.lit("fid=? and bot_parsed > ?",fid, from))
    .all.map { |dd| dd[:bot_parsed].strftime("%F %H:%M:%S") }.join(', ')

    p " -- fid:#{fid} hours_back:#{hours_back} parsed_dates:#{parsed_dates}"
    
    tid_list = nil
    unless tid_list
      tid_list = calc_tid_list_for__report_response_statistic(fid, hours_back)
      .map{|k,vv| dd=vv.map { |el| el[1]  }.minmax;  [k, dd.last-dd.first] }
      p tid_list.map { |e| e[0]  }
    end


    Parallel.map(tid_list,:in_threads=>1) do |rr,idx|
    #tid_list.each do |tid, diff_responses|
      
      tid, diff_responses = rr
      #next if tid!=421615
      #p "tid: #{tid}  diff_resps: #{diff_responses}"

      dd =load_thread_before_date(tid, hours_back)

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

  def self.load_thread_before_date(tid, hours_back=12, detailed_log=false)

    p "---(#{tid}) load_thread_before_date ---hours_back #{hours_back}" if detailed_log

    from = date_now(hours_back)
    to=date_now(0)

    BCTalkParser.set_from_date(hours_back)

    thread_ =  DB[:threads].first(siteid:SID, tid:tid)
    responses = thread_[:responses]
    fid = thread_[:fid]

    page_and_num = PageUtil.calc_last_page(responses+1,20)
    lpage = page_and_num[0]
    lcount = page_and_num[1]

    url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
    url = url_templ % [tid,(lpage-1)*40]

    #check_on_corrected_tpages(tid,lpage)

    downl_pages=BCTalkParser.calc_arr_downl_pages(tid, lpage, lcount, from).take(8)

    finished_downl_pages=[]
    ranks_stat_all=Hash.new(0)

    fisrt_date_less = false

    downl_pages.each do |pp|
      break if fisrt_date_less

        loop do
          begin
            data = BCTalkParser.set_opt({rank:1, parse_signature:false}).parse_thread_page(tid, pp[0])
            finished_downl_pages<<pp[0]

            ranks_stat= data[:stat].group_by{|x| x}.map{|k,vv| [k,vv.size]}.to_h
            p "--load page #{tid} pg #{pp[0]} rank stats #{ranks_stat}" if detailed_log

            [1,2,3,4,5,11].each{|x| ranks_stat_all[x]+= (ranks_stat[x]||0)}
            fisrt_date_less =  data[:first_post_date] <from

            break
          rescue =>ex
            p "--err tid #{tid} pg #{pp} --#{ex}"
            #puts ex.backtrace
          end
        end

    end

    downloaded_pages_str = finished_downl_pages #downl_pages.map { |pp| "#{pp[0]}_#{pp[1]}" }.join(' ')

    if  ranks_stat_all && finished_downl_pages.size>0

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
    
    ranks_stat_all
  end

  def self.check_on_corrected_tpages(tid, lpage)
    tpages = DB[:tpages].filter(Sequel.lit("tid=?", tid)).to_hash(:page,[:postcount,:fp_date])
    
    if tpages[lpage+1]
      
      bad_page = lpage+1
      max= tpages.keys.max
      need_delete=[]
      (bad_page..max).each do |pp| 
        need_delete << pp if tpages[pp] 
      end
      max_post_pnum = DB[:posts].filter(tid:tid).max(:pnum)
      p need_delete+= (max_post_pnum..lpage).to_a
      DB[:tpages].filter( Sequel.lit("tid=? and page in ?", tid, need_delete) ).delete
      DB[:posts].filter( Sequel.lit("tid=? and pnum in ?", tid, need_delete) ).delete
    end


  end

  def self.calc_reliability_for_threads(fid,tid_list, time =24)

    from=date_now(time)
    to=date_now(0)

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable])

    indx=0
    out = []
    tid_list.each do |tid|

      indx+=1
      ## calc reliable
      ranks = DB[:posts].filter( Sequel.lit("tid=? and addeddate > ?", tid, from) )
      .order(:addeddate).select_map(:addedrank)
      

      ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
      sum = ranks_gr.map{ |dd| dd[1] }.sum
      next if sum==0
      
      reliable_ff = 1-( (ranks_gr[1]||0) + (ranks_gr[2]||0) )/sum.to_f
      #p "tid: #{tid} sum #{sum} reliable_ff: #{'%0.2f' % reliable_ff} ranks_gr #{ranks_gr} " 
      
      if sum>20 

        if threads_attr[tid]
          thr_title_cleaned = threads_attr[tid][0].gsub('?', '').strip ####.gsub(/\A[\d_\W]+|[\d_\W]+\Z/, '')
        else
          thr_title_cleaned = tid
        end
        
        out<<"#{indx} ff: #{reliable_ff} ranks #{ranks_gr}  [b]#{thr_title_cleaned}[/b]"
        DB[:threads].filter(siteid:9, tid: tid).update(reliable: reliable_ff)

      end

    end
    out<<"------------"

    @@report_file = "calc_reliable_#{fid}.txt"
    File.write("report/"+@@report_file, out.join("\n"))

  end
##end of class
end
    
