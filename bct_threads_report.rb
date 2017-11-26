require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true

class BctThreadsReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20
  REPORT_FILE = "report_threads_sorted_by_repsonses_%s.html"
  @@report_file=""

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

  def self.report_response_statistic_LIST_FORUMS(list_forums, hours_back =24)

    @@report_file = REPORT_FILE % [list_forums.join('_')]
    File.write(@@report_file, "")

    list_forums.each do |fid|
      report_response_statistic(fid,hours_back,true)
    end

  end

  THREADS_ANALZ_NUM=20

  def self.report_response_statistic(fid, time =24, show_ranks=false)

    from=date_now(time)
    to=date_now(0)

    forum_title = DB[:forums].filter(siteid:SID,fid:fid).first[:title] rescue "no forum"
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable,:responses])


    ##generate
    out = []

    is_forum = true
    bold =  is_forum ? "[b]" : "**"
    bold_end = is_forum ? "[/b]" : "**"

    out<< ""
    out<< ""
    out<<"#{bold}forum: (#{fid}) #{forum_title}#{bold_end} "
    out<<"#{bold}#{from.strftime("%F %H:%M")}  -  #{to.strftime("%F %H:%M")}#{bold_end}"
    out<<"------------"


    ## unreliable threads
    unreliable_threads = threads_attr.select{ |k,v| v[1] && v[1]<0.3   }


    unreliable_tids = unreliable_threads.keys
    unreliable_titles = unreliable_threads.map{|tid,v| "tid:#{tid} #{v[0]}" }

    threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ? and tid not in ?", fid, from, unreliable_tids))
    .select_map([:tid,:responses,:last_post_date])


    max_resps_threads = threads_responses.group_by{|h| h[0]}
    .select{ |k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    #max_resps_threads_tid = max_resps_threads.map{|k,vv| k}

    indx=0
    max_resps_threads.each do |tid, tt|
      indx+=1

      #next if tid!=2198936
      min_date_from_thread_stat=tt.min_by{|x| x[2]}[2] #min_by(&:last_post_date)

      is_reliable = true
      if show_ranks
        ranks = DB[:posts].filter( Sequel.lit("siteid=? and tid=? and addeddate > ?", SID, tid, min_date_from_thread_stat) )
        .order(:addeddate).select_map(:addedrank)
        all_posts_count =  ranks.size

        ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
        #rank_info = [1,2,3,4,5,11].map{|x|  "#{x==11? 'legend': ('rank(%s)' % x)}-#{ranks_gr[x]||0} "}.join(' ')
        rank_info = [1,2,3,4,5,11].map{|x|  "#{ranks_gr[x]||0}"}.join(' ')

        sum = ranks_gr.map{ |dd| dd[1] }.sum
        #is_reliable = (ranks_gr[1]+ranks_gr[2])/sum.to_f <0.7
      
      end

      resps_minmax=tt.map { |el| el[1]  }.minmax
      diff_responses  =resps_minmax[1]-resps_minmax[0]

      #####calculate last page for max number of responses
      page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
      lpage = (page_and_num[0]-1)*40 rescue 0

      url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"

      if show_ranks
        #out<< "#{reliable_str} responses:#{all_posts_count}    from:#{min_date_from_thread_stat.strftime("%F %H:%M")}"
        out<< "responses:#{all_posts_count} ranks:(#{rank_info})"
      else 
        out<< "responses: #{ diff_responses }"
      end

      thr_title_cleaned = threads_attr[tid][0]
      out<<"#{indx} #{url} [b]#{thr_title_cleaned}[/b]"
      out<<""

    end

    if true #show_unreliable_threads
      url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"

      out<< "[color=red]UNRELIABLE THREADS!!![/color]"
      unreliable_threads.each do |tid,v|
        
        page_and_num = PageUtil.calc_last_page(v[2]+1,20)
        lpage = (page_and_num[0]-1)*40 rescue 0
        url = url_templ % [tid, lpage]
        out << "#{url} #{v[0].sub('[PRE]','[ PRE]')}" 
      end
      out<<"------------"
    end    

    @@report_file = REPORT_FILE % [fid] if @@report_file==""
    File.write("report/"+@@report_file, out.join("\n"), mode: 'a')

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
