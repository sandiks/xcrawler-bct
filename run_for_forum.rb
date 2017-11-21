require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_threads_report'

#FORUMS=[159,240,67,52,1]

FORUMS=[67,52,1]
fid = ARGV[1].to_i
HOURS_BACK=8

downl_rank=1

case ARGV[0]
  when 'stat';                  BCTalkParserAdv.load_thread_responses_to_stat_thread(fid, HOURS_BACK,1)
  when 'stat_all';              BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(FORUMS, HOURS_BACK)
  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) 
  when 'load_posts_sorted_max'; BCTalkParserAdv.load_thread_posts_with_max_responses_in_interval(fid,HOURS_BACK) ##load thr-posts 
  when 'analz_thread_posts_of_users_rank1'; BctThreadsReport.analz_thread_posts_of_users_rank1(2250212,HOURS_BACK) ##load thr-posts 
end