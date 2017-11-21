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

FORUMS=[159,240,238]

#FORUMS=[67,52,1]
fid = ARGV[1].to_i
HOURS_BACK=12

downl_rank=1

def run(p1)
  scheduler = Rufus::Scheduler.new
  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.load_forum_thread_responses(FORUMS, HOURS_BACK)
  end

  scheduler.join
end

case ARGV[0]
  when 'stat';                  BCTalkParserAdv.load_forum_thread_responses(fid, HOURS_BACK)
  when 'stat_all';              BCTalkParserAdv.list_load_forum_thread_responses(FORUMS, HOURS_BACK)
  when 'load_posts_sorted_max'; BCTalkParserAdv.load_max_responses_threads_posts_in_interval(fid,HOURS_BACK) ##load thr-posts 
  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) 
  
  when 'stat_rep';              BctThreadsReport.forum_threads_with_max_answers(fid, HOURS_BACK,true) 
  when 'stat_all_rep';          BctThreadsReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK) 
  when 'analz_thread_posts_of_users_rank1'; BctThreadsReport.analz_thread_posts_of_users_rank1(2250212,HOURS_BACK) ##load thr-posts 
  when 'show_forums_threads_with_count_users_rank'; BctThreadsReport.show_forums_threads_with_count_users_rank(fid)

  when 'scheduler';             run(30)
end
