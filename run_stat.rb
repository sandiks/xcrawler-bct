
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


##   ruby bctalk_stat.rb stat_all
##   ruby bctalk_stat.rb load_posts_sorted_max 159
##   ruby bctalk_stat.rb stat_all_rep
##   ruby bctalk_stat.rb stat 67 24


case ARGV[0]
  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) ##load posts
  when 'load_unreliable';       BCTalkParserAdv.load_unreliable_threads(fid) ##load posts
  
  when 'stat_rep';              BctThreadsReport.report_response_statistic_for_forum_threads(fid, HOURS_BACK,true) 
  when 'stat_all_rep';          BctThreadsReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK) 
  when 'report_forums_active_threads_with_users_rank'; BctThreadsReport.report_forums_active_threads_with_users_rank(fid)

end
