require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true

class BctThreadsReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20
  REPORT_FILE = "report_response_statistic_%s.html"
  @@report_file=""

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

  def self.report_response_statistic_LIST_FORUMS(list_forums, hours_back =24)

    @@report_file = REPORT_FILE % [list_forums.join('_')]
    File.write(@@report_file, "")

    list_forums.each do |fid|
      report_response_statistic(fid,hours_back,true)
    end

  end

  def self.calc_tid_list_for__report_response_statistic(fid, hours_back =24, threads_num=20)

    from=date_now(hours_back)

    unreliable_threads = []
    #unreliable_threads = DB[:threads].filter(Sequel.lit("fid=? and reliable<0.3",fid)).select_map(:tid)
    #if unreliable_threads.any?  Sequel.lit("fid=? and last_post_date > ? and tid not in ?",fid, from, unreliable_threads)
    
    threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ?",fid, from))
    .select_map([:tid,:responses,:last_post_date])

    sorted_thread_stats = threads_responses.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1 && v.all?{|tt2| tt2[1] <300 } }
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax;  dd.last-dd.first }
    .reverse.take(threads_num)


  end

  def self.report_response_statistic(fid, hours_back =24, threads_num=20, need_sort_by_reliable=true)

    out = []

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title] rescue "no forum"
    ##generate

    indx=0
    
    tid_list = calc_tid_list_for__report_response_statistic(fid, hours_back, threads_num)
    .map{|k,vv| dd=vv.map { |el| el[1]  }.minmax;  [k, dd.last-dd.first, dd.last] }

    topics=[]
    tid_list.each do |tid, diff_responses, last_responses_num|
    
      indx+=1
      thread = DB[:threads].first(tid: tid)
      reliable= thread[:reliable]||0
      thr_title = thread[:title].gsub('??','')
      last_responses_num = thread[:responses]
      #next if tid!=421615
 
      #####calculate last page for max number of responses

      page_and_num = PageUtil.calc_last_page(last_responses_num+1,20)
      last_page = (page_and_num[0]-1)*20 rescue 0
      url = "https://bitcointalk.org/index.php?topic=#{tid}.#{last_page}"

      thr_title = itd unless thr_title    
      url = "#{url} [b]#{thr_title}[/b]"
      topics <<{reliable: reliable, responses:diff_responses, url: url}

    end

    from=date_now(hours_back)
    parsed_dates = DB[:forums_stat].filter(Sequel.lit("fid=? and bot_parsed > ?",fid, from)).order(:bot_parsed).select_map(:bot_parsed)

    p "[start]  ---report_response_statistic --hours_back: #{hours_back} --parsed_dates: #{parsed_dates}" 
    
    first = parsed_dates.first
    last = parsed_dates.last

    p "[start] report_response_statistic  -- from: #{first.strftime("%F %H:%M")} to: #{last.strftime("%F %H:%M")}"

    out<< ""
    out<<"[b]forum: (#{fid}) #{forum_title}[/b] "
    out<<"[b]#{first.strftime("%F %H:%M")}  -  #{last.strftime("%F %H:%M")}[/b]"
    out<<"------------"

    ## generate report 
    if need_sort_by_reliable

      topics.sort_by{|dd| -dd[:reliable]}.each do |topic|
        reliable = topic[:reliable]
        out<< "reliability #{ '%0.2f' % reliable} responses: #{ topic[:responses] }"
        out<< "#{topic[:url]}"
        out<<""
      end

    else
      topics.sort_by{|dd| -dd[:responses]}.each do |topic|
        out<< "responses: #{ topic[:responses] } #{topic[:url]}"
        out<<""
      end
    end

    @@report_file = REPORT_FILE % [fid] if @@report_file==""
    File.write("report/" + @@report_file, out.join("\n"))

  end

  def self.unreliable_threads(fid, hours_back =24)
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable])
    unreliable_threads = threads_attr.select{ |k,v| v[1] && v[1]<0.3   }

    unreliable_tids = unreliable_threads.keys
    unreliable_titles = unreliable_threads.map{|tid,v| "tid:#{tid} #{v[0]}" }
    out = []

    if false 
      out<< "[color=red]UNRELIABLE THREADS!!![/color]"
      unreliable_threads.each do |tid,v|
        page_and_num = PageUtil.calc_last_page(v[2]+1,20)
        lpage = (page_and_num[0]-1)*20 rescue 0
        url = "https://bitcointalk.org/index.php?topic=%s.%s" % [tid, lpage]
        out << "#{url} #{v[0].sub('[PRE]','[ PRE]')}" 
      end
      out<<"------------"
    end    
  end

  def self.analz_thread_posts_of_users(tid, hours_back =24)
    from=date_now(hours_back)
    to=date_now(0)

    threads_title = DB[:threads].first(siteid:SID,tid:tid)[:title]
    out = []

    type='f'
    bold =  "[b]"
    bold_end = "[/b]" # "**"
    url = "https://bitcointalk.org/index.php?topic=#{tid}"

    out<< ""
    out<<"#{bold}thread: (#{tid}) #{threads_title}#{bold_end} url: #{url}"
    out<<"#{bold}#{from.strftime("%F %H:%M")}  -  #{to.strftime("%F %H:%M")}#{bold_end}"
    out<<"------------"

    posts = DB[:posts].filter( Sequel.lit("siteid=? and tid=? and addeddate > ?", SID, tid, from) )
    .order(:addeddate).select(:body,:addedby, :addedrank, :addeddate).all

    posts.each do |pp|
      out<<"----------"
      out<< "#{pp[:addedby]}(#{pp[:addedrank]}) date: #{pp[:addeddate].strftime("%F %H:%M")}"
      out<<"----------"
      out<< pp[:body]
      out<<""
      out<<""

    end
    fpath ="report/analz_thread_posts_of_users_#{tid}_hours_#{hours_back}.html"
    File.write(fpath, out.join("\n"))
  end

  def self.report_forums_active_threads_with_users_rank(fid)
    from=date_now(1)

    threads_stats = DB[:threads_stat].filter(Sequel.lit("fid=? and added > ?", fid, from)).all

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title] rescue "no forum"

    threads_titles = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, :title)
    out = []

    type='f'
    bold =  "[b]"
    bold_end = "[/b]" # "**"

    out<<"#{bold}forum: (#{fid}) #{forum_title}#{bold_end}"

    threads_stats.each do |tt|
      tid = tt[:tid]
      page=(tt[:last_page]-1)*40 rescue 0
      url = "https://bitcointalk.org/index.php?topic=#{tid}.#{page}"

      out<< ""
      out<<"#{bold}thread: (#{tid}) #{threads_titles[tid]}#{bold_end} url: #{url}"
      out<<"#{bold}#{tt[:start_date].strftime("%F %H:%M")}  -  #{tt[:end_date].strftime("%F %H:%M")}#{bold_end}"
      rr=[tt[:r1_count],tt[:r2_count],tt[:r3_count],tt[:r4_count],tt[:r5_count],tt[:r11_count]]
      sum = rr.sum.round(0)
      out<< "sum resps: #{sum}"
      out+=  (0..5).map { |i| "#{i==5 ? 'legend': 'rank-'+(i+1).to_s}: #{rr[i]} (#{'%0.1f' % (rr[i]/sum.to_f*100)})"  }

      out<<"------------"

    end
    fpath ="show_forums_threads_with_count_users_rank.html"
    File.write(fpath, out.join("\n"))
  end

end
