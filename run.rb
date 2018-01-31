require 'rufus-scheduler'
require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_users_report'
require_relative  'bct_threads_report'

##    159   Announcements (Altcoins)
##    240   Tokens (Altcoins)
##    238   bounty (Altcoins)

##    52    Services
##    84    Service Announcements
##    85    Service Discussion
##    197   Service Announcements (Altcoins)
##    198   Service Discussion (Altcoins)
##    67    altcoin discussion
##    212   Micro Earnings
##    1     Bitcoin Discussion
##    72     Альтернативные криптовалюты

FORUMS=[67,1,159,240]
HOURS_BACK=78

def stat

  hours=24
  #BCTalkParserAdv.save_thread_responses_statistics(fid, hours)  
  BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(FORUMS, hours)  
end

def calc_reliablitiy(fid)
  
  hours=48
  tid_list= nil
  
  BCTalkParserAdv.save_thread_responses_statistics(fid, hours)  
  
  if true
    
    BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid,hours)
    #BCTalkParserAdv.calc_reliability_for_threads(fid,nil,hours)
    
    BctThreadsReport.report_response_statistic(fid, tid_list, hours, false) ##show 30 threads
    #BctUsersReport.report_users_sorted_by_merit_for_day(fid, hours) 

  end

end

def merit(fid)

  hours=72
  fid = [159,240]
  #BCTalkParserAdv.save_thread_responses_statistics(fid, hours)
  BctUsersReport.report_users_sorted_by_merit_for_day(fid, hours) 
end

def load_thread_and_report_post
  fid=
  tid=2384512
  #BCTalkParserAdv.load_thread_pages_before_date(fid, tid,24*3, 0)
  #BctUsersReport.report_users_sorted_by_merit_for_day(fid, hours) 

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
  from=date_now(24*4)
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

  when 'stat'; stat
  when 'calc'; calc_reliablitiy(fid)
  when 'merit'; merit(fid)
  when 'clean_table'; clean_table

  when 'thread'; BCTalkParserAdv.load_thread_before_date(ARGV[1].to_i,hours)
  when 'set_unreliable'; set_unreliable(ARGV[1].to_i)

end