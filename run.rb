require 'rufus-scheduler'
require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_users_report'
require_relative  'bct_threads_report'

##    159   Announcements (Altcoins)
##    240   Tokens (Altcoins)
##    52    Services
##    84    Service Announcements
##    85    Service Discussion
##    197   Service Announcements (Altcoins)
##    198   Service Discussion (Altcoins)
##    67    altcoin discussion
##    238   bounty (Altcoins)
##    212   Micro Earnings
##    1     Bitcoin Discussion

FORUMS=[52,84,85,197,198,159,240]
HOURS_BACK=72

#########
def stat(fid)
  hours=24
  tid_list = nil
  BCTalkParserAdv.save_thread_responses_statistics(fid, hours)  
  BctThreadsReport.report_response_statistic(fid, tid_list, hours, false)
end

def calc_reliablitiy
  
  fid=159
  hours=24
  #tid_list= BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid,hours)
  
  tid_list = [2006010, 2666727, 2388064, 2649303, 735170, 2159012, 2505106, 1365894, 2268691, 2090765, 2515675, 2313170, 2040221, 1216479, 2595620, 1381323, 2482605, 2638878, 2350803, 2166510]
  BCTalkParserAdv.calc_reliability_for_threads(fid, tid_list) if fid==159||fid==240
end

#calc_reliablitiy

def job
  BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(FORUMS, HOURS_BACK) ##ruby bctalk_stat.rb stat_all
  #BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(159,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 159
  #BctThreadsReport.report_response_statistic_LIST_FORUMS(FORUMS,HOURS_BACK)
end

def load_thread_and_report_post
  tid=2384512
  BCTalkParserAdv.load_thread_before_date(159,2384512,240)
  BctThreadsReport.analz_thread_posts_of_users(tid,120)
end


##  generate report with thread name and users with rank>3
def load_post_and_gen_report
  fid=67
  pg=3
  hours=24

  #BCTalkParser.set_from_date(hours).parse_forum(fid,pg,true)
  BctUsersReport.gen_threads_with_stars_users(fid, hours)
end


DB = Repo.get_db

def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

def set_unreliable(tid)
  #tid=2423910
  fid=DB[:threads].first(tid:tid)[:fid]
  DB[:threads_attr].insert({fid:fid,tid:tid,reliable:0, modified: date_now(0)})
end
#set_unreliable(tid)

def run(p1)
  scheduler = Rufus::Scheduler.new
  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.save_thread_responses_statistics(FORUMS, HOURS_BACK)
  end
  scheduler.join
end

fid = ARGV[1].to_i
hours = ARGV[2].to_i

case ARGV[0]

  when 'stat'; stat(fid)
  when 'calc'; calc_reliablitiy
  when 'job'; job

  when 'thread'; BCTalkParserAdv.load_thread_before_date(ARGV[1].to_i,hours)
  when 'set_unreliable'; set_unreliable(ARGV[1].to_i)

end


#p BCTalkParser.parse_thread_page(2398403,12)
