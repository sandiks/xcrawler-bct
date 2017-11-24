require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'


DB = Repo.get_db

def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

THREADS_ANALZ_NUM=15
SID=9
FID=159
TID=1847292
HOURS_BACK=24


def show_responses_and_ranks_for_thread(fid,tid)
  from=date_now(HOURS_BACK)
  show_ranks=true

  ##-----------------------
  p "from #{from.strftime("%F %k:%M ")}"
  threads_titles = DB[:threads].filter(siteid:SID,fid:fid).to_hash(:tid, :title)


  forum_stat = DB[:forums_stat].filter(Sequel.lit("sid=? and fid=? and bot_parsed > ?", SID,fid,from))
  .select_map(:bot_parsed)

  parsed_forum_date_min = forum_stat.min.to_datetime
  p "parsed_forum_date_min #{parsed_forum_date_min.strftime("%F %k:%M ")}"

  ##--------
  threads_stat = DB[:threads_responses].filter(Sequel.lit("sid=? and fid=? and last_post_date > ?", SID,fid, parsed_forum_date_min))
  .select_map([:tid,:responses,:last_post_date])


  p max_resps_threads = threads_stat.group_by{|h| h[0]}
  .select{|k,v| k==tid}
  .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
  .reverse.take(THREADS_ANALZ_NUM)

  out=[]
  max_resps_threads.each do |tid, tt|

    #p tpages = DB[:tpages].filter(Sequel.lit("siteid=? and tid=?", SID, tid)).to_hash(:page,[:postcount])


    if show_ranks
      ranks = DB[:posts].filter( Sequel.lit("siteid=? and tid=? and addeddate > ?", SID, tid, parsed_forum_date_min) )
      .order(:addeddate).select_map(:addedrank)

      ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
      rank_info = [1,2,3,4,5,11].map{|x|  "#{x==11? 'legend': ('rank(%s)' % x)}-#{ranks_gr[x]||0} "}.join(' ')
    end

    p  resps_minmax=tt.map { |el| el[1]  }.minmax

    page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
    lpage = (page_and_num[0]-1)*40 rescue 0
    url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"
    out<< "responses: #{ resps_minmax[1]-resps_minmax[0]} "
    out<< "#{rank_info}" if show_ranks
    out<< "#{url}    #{threads_titles[tid]}"
    out<< ""
  end
  puts out
end


def thread_posts_stats(tid,hours_back=24) ## for site, show when you click 'post' button

  from = date_now(hours_back)

  p tpages = DB[:tpages].filter(Sequel.lit("tid=?", tid)).to_hash(:page,[:postcount,:fp_date]).first(20)

  responses =  DB[:threads].first(siteid:SID, tid:tid)[:responses]


  page_and_num = PageUtil.calc_last_page(responses+1,20)
  lpage = page_and_num[0]
  lcount = page_and_num[1]
  p "---thread_stats tid:#{tid} responses: #{responses} last #{page_and_num}"

  url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
  url = url_templ % [tid,(lpage-1)*40]

  downl_pages=BCTalkParser.calc_arr_downl_pages(tid, lpage, lcount, from).take(10)

  ranks = DB[:posts].filter( Sequel.lit("tid=? and addeddate > ?", tid, from) )
  .order(:addeddate).select(:addedby,:addedrank,:addeddate).all

  p "---posts count: #{ranks.size}"
  puts ranks.map { |dd| "#{dd[:addedby]} #{dd[:addedrank]} date: #{dd[:addeddate].strftime("%F %H:%M")}"   }

end
#BctThreadsReport.analz_thread_posts_of_users_rank1(2009966,48) ##load thr-posts 
#BCTalkParserAdv.load_thread_before_date(159,1847292,24)

show_responses_and_ranks_for_thread(FID,TID)

#thread_posts_stats(1847292,24)
