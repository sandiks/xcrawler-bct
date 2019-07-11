require 'rufus-scheduler'
require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_users_report'
require_relative  'bct_threads_report'
require_relative  'bct_bounty_report'

##    159   Announcements (Altcoins)
##    240   Tokens (Altcoins)
##    160   Mining (Altcoins)

##    1     Bitcoin Discussion
##    52    Services
##    67    altcoin discussion
##    72    Альтернативные криптовалюты
##    83    Scam Accusations
##    84    Service Announcements
##    85    Service Discussion
##    197   Service Announcements (Altcoins)
##    198   Service Discussion (Altcoins)
##    212   Micro Earnings

FORUMS=[160,83,67,72,1]
HOURS_BACK=78

def  all_forums_check

  hours=2*24
  #BCTalkParserAdv.save_thread_responses_statistics(fid, hours)  
  BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(FORUMS, hours)  
end

def load_calc_report(fid)
  
  hours = 12*24
  #BCTalkParserAdv.save_thread_responses_statistics(fid, 24)
  
  BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid, hours, 120) 
  BctThreadsReport.report_response_statistic(fid, hours, 20, true)
  #BctUsersReport.report_users_sorted_by_merit_for_day(fid, hours) 

end


def fast_check(fid)
  hours =7*24
  
  #BCTalkParserAdv.save_thread_responses_statistics(fid, hours)  
  BctThreadsReport.report_response_statistic(fid, hours, 10, true) ##show 40 threads
end


def load_thread_and_report_post
  fid=
  tid=2384512
  #BCTalkParserAdv.load_thread_pages_before_date(fid, tid,24*3, 0)

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



#########
DB = Repo.get_db

def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

def clean_table
  from=date_now(24*5)
  p DB[:threads_responses].where{parsed_at<from}.delete
end

def set_unreliable(tid)
  #tid=2423910
  fid=DB[:threads].first(tid:tid)[:fid]
  DB[:threads_attr].insert({fid:fid,tid:tid,reliable:0, modified: date_now(0)})
end

#set_unreliable(tid)

#####
fid = ARGV[1].to_i
hours = ARGV[2].to_i

case ARGV[0]

  when 'all_check'; all_forums_check

  when 'fast'; fast_check(fid)
  when 'calc'; load_calc_report(fid)

  when 'clean_table'; clean_table

  when 'thread'; BCTalkParserAdv.load_thread_before_date(ARGV[1].to_i,hours)
  when 'set_unreliable'; set_unreliable(ARGV[1].to_i)

end