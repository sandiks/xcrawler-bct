require 'rufus-scheduler'

require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_threads_report'


##    159  Announcements (Altcoins)
##    240  Tokens (Altcoins)
##    52   Services
##    85   service discussion
##    67   altcoin discussion

##    238  bounty (Altcoins)
##    212   Micro Earnings

FORUMS=[159,240]

fid = ARGV[1].to_i
hours = ARGV[2].to_i
HOURS_BACK=24

downl_rank=1

def run(p1)
  scheduler = Rufus::Scheduler.new
  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.load_forum_thread_responses(FORUMS, HOURS_BACK)
  end

  scheduler.join
end


##   ruby bctalk_stat.rb stat_all
##   ruby bctalk_stat.rb load_posts_sorted_max 159
##   ruby bctalk_stat.rb stat_all_rep
##   ruby bctalk_stat.rb stat 67 24

def job
  BCTalkParserAdv.list_load_forum_thread_responses(FORUMS, HOURS_BACK) ##ruby bctalk_stat.rb stat_all

  BCTalkParserAdv.load_max_responses_threads_posts_in_interval(159,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 159
  BCTalkParserAdv.load_max_responses_threads_posts_in_interval(240,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 240

  #BctThreadsReport.show_response_statistic_for_forum_threads(fid, HOURS_BACK,true)
  BctThreadsReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK)
end


case ARGV[0]
  when 'job';                   job
  when 'stat';                  BCTalkParserAdv.load_forum_thread_responses(fid, hours)
  when 'stat_all';              BCTalkParserAdv.list_load_forum_thread_responses(FORUMS, HOURS_BACK)
  when 'load_posts_sorted_max'; BCTalkParserAdv.load_max_responses_threads_posts_in_interval(fid,HOURS_BACK) ##load thr-posts 
  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) 
  when 'load_unreliable';       BCTalkParserAdv.load_unreliable_threads(fid)
  
  when 'stat_rep';              BctThreadsReport.show_response_statistic_for_forum_threads(fid, HOURS_BACK,true) 
  when 'stat_all_rep';          BctThreadsReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK) 
  when 'report_forums_active_threads_with_users_rank'; BctThreadsReport.report_forums_active_threads_with_users_rank(fid)

  when 'scheduler';             run(30)
end
#BctThreadsReport.analz_thread_posts_of_users_rank1(2009966,48) ##load thr-posts 

BCTalkParserAdv.load_thread_before_date(240,2078239,24)