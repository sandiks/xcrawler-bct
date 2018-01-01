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

  THREADS_ANALZ_NUM=30

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
    end

    Parallel.map(tid_list,:in_threads=>1) do |rr,idx|
    #tid_list.each do |tid, resps_diff|
      
      tid, resps_diff = rr
      #next if tid!=421615
      #p "tid: #{tid}  diff_resps: #{resps_diff}"
      dd =load_thread_before_date(tid, hours_back)
    end

    tid_list.map { |e| e[0]  }

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

    downl_pages= calc_arr_downl_pages(tid, lpage, lcount, from).take(8)

    finished_downl_pages=[]
    ranks_stat_all=Hash.new(0)

    fisrt_date_less = false

    downl_pages.each do |pp|

      break if fisrt_date_less

      loop do
          
        begin
          #data = BCTalkParser.set_opt({rank:3, parse_signature:false}).parse_thread_page(tid, pp[0])

          data = parse_page_and_save_to_tpage_ranks(tid, pp[0]) ##  save only user ranks
          
          finished_downl_pages<<pp[0]

          ranks_stat= data[:stat].group_by{|x| x}.map{|k,vv| [k,vv.size]}.to_h
          #p "--load page #{tid} pg #{pp[0]} rank stats #{ranks_stat}" if detailed_log

          [1,2,3,4,5,11].each{|x| ranks_stat_all[x]+= (ranks_stat[x]||0)}
          fisrt_date_less =  data[:first_post_date] <from

          break

        rescue =>ex
          p "--err tid #{tid} pg #{pp} --#{ex}"
          #puts ex.backtrace
        end

      end

    end ## end each

    downloaded_pages_str = finished_downl_pages #downl_pages.map { |pp| "#{pp[0]}_#{pp[1]}" }.join(' ')

    if  ranks_stat_all && finished_downl_pages.size>0
      
      dd=[ranks_stat_all[1],ranks_stat_all[2],ranks_stat_all[3],
      ranks_stat_all[4], ranks_stat_all[5], ranks_stat_all[11]]
      
      sum = dd.sum
      reliable = 1- (dd[0]+dd[1])/sum.to_f     
      DB[:threads].filter(tid: tid).update(reliable: reliable) if sum>10
    end

    planned_str=downl_pages.map { |pp| "#{pp[0]}" }.join(' ')
    
    p "---load_thr #{tid} last pg,count: #{page_and_num}".ljust(50)+
    "planned:#{planned_str.ljust(30)}  down:#{finished_downl_pages} ranks_stat_all: #{dd}" if downl_pages.size>0     
    
    ranks_stat_all
  end

  def self.calc_arr_downl_pages(tid, lp_num, lp_post_count, start_date)
    downl_pages=[]
    tpages = DB[:tpage_ranks].filter(tid:tid).to_hash(:page,[:postcount,:fp_date])
    
    need_downl_preLast_pages=true

    mc0=0
    if tpages[lp_num]
      mc0=tpages[lp_num][0]
      first_postdate = tpages[lp_num][1]
      need_downl_preLast_pages = first_postdate && first_postdate.to_datetime> start_date
    end
    downl_pages<<[lp_num,mc0, first_postdate] if lp_post_count-mc0>=2

    #added pre-last pages
    if need_downl_preLast_pages

      (lp_num-1).downto(lp_num-30) do |pg|
        break if pg<1
        
        post_count=0
        lp_date=nil
        if tpages[pg]
          post_count =  tpages[pg][0]
          lp_date = tpages[pg][1]
          date_is_out = lp_date && lp_date.to_datetime< start_date
        end

        downl_pages<<[pg, post_count, lp_date] if post_count!=THREAD_PAGE_SIZE 
        break if date_is_out
      end
    end

    downl_pages
  end
######### download thread page and save ranks to 'tpage_ranks'

  def self.get_link(tid, page=1)
    pp = (page>1 ? "#{(page-1)*THREAD_PAGE_SIZE}" : "0")
    link = "https://bitcointalk.org/index.php?topic=#{tid}.#{pp}"
  end

  ##11-legendary
  def self.detect_user_rank(td)
    stars = td.css('div.smalltext > img[alt="*"]')
    legend = stars.first['src'].end_with?("legendary.gif") rescue false
    staff = stars.first['src'].end_with?("staff.gif") rescue false
    rank = legend || staff ? 11 : stars.size
  end

  def self.parse_post_date(date_str)
    now = date_now
    date = DateTime.parse(date_str) rescue DateTime.new(1900,1,1) #.new_offset(3/24.0)
    date>now ? date-1 : date
  end

  def self.parse_page_and_save_to_tpage_ranks(tid, page)

    return if page<1
    
    link = get_link(tid,page)
    fname = "html/bctalk-tid#{tid}-p#{page}.html"
    page_html = Nokogiri::HTML(download_page(link))

    post_class = page_html.css("div#bodyarea > form > table.bordercolor tr").first.attr('class')

    thread_posts = page_html.css("div#bodyarea > form > table.bordercolor tr[class^='#{post_class}']")

    posts =[]
    
    ##parse posts
    thread_posts.map do |post|

      post_tr = post.css('table tr > td > table > tr').first #td[class~="windowbg windowbg2"]
      sign_tr = post.css('table  tr > td > table >  tr div.signature').first

      td1=post_tr.css('td')[0] ##user info
      td2=post_tr.css('td')[1] ## post info

      #user info
      rank=0
      addeduid=0
      if td1
        link = td1.css('a')[0]
        url = link["href"]
        addeduid = url.split('=').last.to_i
        rank = detect_user_rank(td1)
      end

      post_date_str = td2.css('td:nth-child(2) div.smalltext').text
      post_date = parse_post_date(post_date_str)

      posts<<{
        addeduid:addeduid,
        addedrank:rank,
        addeddate: post_date,
        pnum:page
      }
    end

    page_ranks = posts.map{|x| x[:addedrank]}
    first_post_date = posts.first[:addeddate]

    grouped_ranks = page_ranks.group_by{|r| r}.map{|r, pp| ["r#{r}", pp.size]}.to_h

    Repo.insert_or_update_tpage_ranks(tid, page, posts.size, first_post_date, grouped_ranks)
    {first_post_date:first_post_date, stat:page_ranks} 

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

  def self.calc_reliability_for_threads(fid,tid_list, hours_back =24)

    from=date_now(hours_back)
    to=date_now(0)

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title]
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable])

    indx=0
    out = []
    
    unless tid_list 
      tid_list = calc_tid_list_for__report_response_statistic(fid, hours_back)
      .map{|k,vv| dd=vv.map { |el| el[1]  }.minmax;  [k, dd.last-dd.first] }
      #p tid_list.map { |e| e[0]  }
    end

    tid_list.each do |tid, resps_diff|

      indx+=1
      ## calc reliable

      ranks = DB[:tpage_ranks].filter( Sequel.lit("(tid=? and fp_date > ?)", tid, from) ).select_map([:r1,:r2,:r3,:r4,:r5,:r11])
      
      all_ranks = [0,0,0,0,0,0]
      ranks.each do |arr|
        6.times {|t| all_ranks[t] += arr[t]||0 } 
      end

      sum = all_ranks.sum
      sum_r1_r2 = all_ranks[0]+all_ranks[1]
      next if sum==0
      
      reliable_ff = 1- sum_r1_r2/sum.to_f
      if sum>5
        if threads_attr[tid]
          thr_title_cleaned = threads_attr[tid][0].gsub('?', '').strip ####.gsub(/\A[\d_\W]+|[\d_\W]+\Z/, '')
        else
          thr_title_cleaned = tid
        end
        
        out<<"#{indx} tid: #{tid} ff: #{'%0.2f' % reliable_ff} ranks #{all_ranks}  [b]#{thr_title_cleaned}[/b]"
        DB[:threads].filter(siteid:9, tid: tid).update(reliable: reliable_ff)
      end

    end
    out<<"------------"

    @@report_file = "calc_reliable_#{fid}.txt"
    File.write("report/"+@@report_file, out.join("\n"))

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
        load_thread_before_date(tid,12)
      end

  end  
##end of class
end
    
