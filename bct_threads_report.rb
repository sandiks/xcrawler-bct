require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true

class BctThreadsReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20
  @@report_file

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

  def self.report_response_statistic_LIST_FORUMS(list_forums, hours_back =24)

    @@report_file = "report_threads_sorted_by_repsonses_#{list_forums.join('_')}.html"
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
    threads_attr = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, [:title,:reliable])


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

    threads_responses = DB[:threads_responses].filter(Sequel.lit("sid=? and fid=? and last_post_date > ?", SID,fid,from))
    .select_map([:tid,:responses,:last_post_date])

    ##show unreliable threads
    unreliable_tids=[]
    if true #show_unreliable_threads
      unreliable_threads = DB[:threads].filter(Sequel.lit("fid=? and reliable<0.3",fid)).select(:tid, :title).all
      unreliable_tids = unreliable_threads.map{|x| x[:tid]}
      unreliable_titles = unreliable_threads.map{|x| x[:title].gsub('?', '').strip }

      out<< "[color=red]UNRELIABLE THREADS!!![/color]"
      out+= unreliable_titles
      out<<"------------"
    end

    max_resps_threads = threads_responses.group_by{|h| h[0]}
    .select{ |k,v| v.size>1 && (!unreliable_tids.include?(k)) }
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    #max_resps_threads_tid = max_resps_threads.map{|k,vv| k}

    indx=0
    max_resps_threads.each do |tid, tt|
      indx+=1

      #next if tid!=2198936
      min_date_from_thread_stat=tt.min_by{|x| x[2]}[2] #min_by(&:last_post_date)

      if show_ranks
        ranks = DB[:posts].filter( Sequel.lit("siteid=? and tid=? and addeddate > ?", SID, tid, min_date_from_thread_stat) )
        .order(:addeddate).select_map(:addedrank)
        all_posts_count =  ranks.size

        ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
        rank_info = [1,2,3,4,5,11].map{|x|  "#{x==11? 'legend': ('rank(%s)' % x)}-#{ranks_gr[x]||0} "}.join(' ')
      end

      resps_minmax=tt.map { |el| el[1]  }.minmax
      diff_responses  =resps_minmax[1]-resps_minmax[0]

      #####calculate last page for max number of responses
      page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
      lpage = (page_and_num[0]-1)*40 rescue 0

      url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"

      reliable=threads_attr[tid][1]
      if reliable && reliable <0.3
        reliable_str="reliable: #{'%0.2f' % reliable }  [color=red]!!!UNRELIABLE[/color]"
      end

      thr_title_cleaned = threads_attr[tid][0].gsub('?', '').strip ####.gsub(/\A[\d_\W]+|[\d_\W]+\Z/, '')
      out<<"#{indx} #{url} #{thr_title_cleaned}"
      #out<< "responses: #{ diff_responses }"

      if show_ranks
        out<< "#{reliable_str} downloaded posts:#{all_posts_count}    from:#{min_date_from_thread_stat.strftime("%F %H:%M")}"
        out<< "#{rank_info}"
      end

      out<<""

    end
    @@report_file = "report_threads_sorted_by_repsonses_#{fid}.html" unless @@report_file
    File.write(@@report_file, out.join("\n"), mode: 'a')

  end

  def self.analz_thread_posts_of_users_rank1(tid, time =24)
    from=date_now(time)
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
      out<< "added: #{pp[:addedby]}"
      out<< " date: #{pp[:addeddate].strftime("%F %H:%M")}"
      out<<"----------"

      out<< pp[:body]
    end
    fpath ="analz_thread_posts_of_users_rank1.html"
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
