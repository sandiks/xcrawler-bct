require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true

class BctThreadsReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end
  
  def self.list_forum_threads_with_max_answers(list_forums, hours_back =24)
    
    File.write("forums_thread_f.html", "")
    
    list_forums.each do |fid|
      forum_threads_with_max_answers(fid,hours_back)
    end

  end
  
  THREADS_ANALZ_NUM=25

  def self.forum_threads_with_max_answers(fid, time =24, show_ranks=false)
    from=date_now(time)
    to=date_now(0)

    title = DB[:forums].filter(siteid:SID,fid:fid).first[:title] rescue "no forum"
    threads_titles = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, :title)

    stat = DB[:threads_responses].filter(Sequel.lit("sid=? and fid=? and last_post_date > ?", SID,fid,from)).select_map([:tid,:responses,:last_post_date])

    ##generate
    out = []    

    type='f'
    
    is_forum = type =='f' 
    bold =  is_forum ? "[b]" : "**"
    bold_end = is_forum ? "[/b]" : "**"

    out<< ""
    is_forum ? out<<"#{bold}forum: (#{fid}) #{title}#{bold_end}" : out<<"Most active(for #{time} hours) threads from \"#{bold}#{title}#{bold_end}\""
    out<<"#{bold}#{from.strftime("%F %H:%M")}  -  #{to.strftime("%F %H:%M")}#{bold_end}"
    out<<"------------"

    max_resps_threads = stat.group_by{|h| h[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
    .reverse.take(THREADS_ANALZ_NUM)

    max_resps_threads.each do |tid, tt|

      #next if tid!=2198936
      min_date_from_thread_stat=tt.min_by{|x| x[2]}[2] #min_by(&:last_post_date)

      if show_ranks
        ranks = DB[:posts].filter( Sequel.lit("siteid=? and tid=? and addeddate > ?", SID, tid, min_date_from_thread_stat) )
        .order(:addeddate).select_map(:addedrank)

        ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
        rank_info = [1,2,3,4,5,11].map{|x|  "#{x==11? 'legend': ('rank(%s)' % x)}-#{ranks_gr[x]||0} "}.join(' ')
      end

      resps_minmax=tt.map { |el| el[1]  }.minmax

      page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
      lpage = (page_and_num[0]-1)*40 rescue 0      
      
      url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"
      out<< "responses: #{ resps_minmax[1]-resps_minmax[0]} "
      out<< "#{rank_info}" if show_ranks
      out<< "#{url}    #{threads_titles[tid]}"
      out<< ""
    end
    out<<"----------"
    report_name = is_forum ? "forums_thread_f" : "forums_thread_t" 

    fpath ="#{report_name}.html"
    File.write(fpath, out.join("\n"), mode: 'a')

  end

  def self.analz_thread_posts_of_users_rank1(tid, time =24)
    from=date_now(time)
    to=date_now(0)

    threads_title = DB[:threads].filter(siteid:SID,tid:tid).select_map(:title).first
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

  def self.show_forums_threads_with_count_users_rank(fid)
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
      out<< "rank-1: #{tt[:r1_count]}\nrank-2: #{tt[:r2_count]}\nrank-3: #{tt[:r3_count]} \nrank-4: #{tt[:r4_count]}\nrank-5: #{tt[:r5_count]}\nlegend: #{tt[:r11_count]}"

      out<<"------------"

    end
    fpath ="show_forums_threads_with_count_users_rank.html"
    File.write(fpath, out.join("\n"))
  end

end
