require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_threads_report'

#FORUMS=[159,240,67,52,1]

FORUMS=[67,52,1]
fid = ARGV[1].to_i
HOURS_BACK=12

downl_rank=1

case ARGV[0]
  when 'max_responses';         BCTalkParserAdv.save_thread_responses_statistics(fid,8)
  when 'max_responses_list';    fids= ARGV[1].split('_').map(&:to_i); BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(fids,4)
  when 'thread';                BCTalkParserAdv.load_thread_before_date(ARGV[1].to_i, ARGV[2].to_i, true)## tid pg hours
  when 'calc_thread';           BCTalkParserAdv.calc_reliability_for_threads(fid, [ARGV[2].to_i], 48)

  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) 
  when 'load_posts_sorted_max'; BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid,HOURS_BACK) ##load thr-posts 
  when 'analz_thread_posts_of_users_rank1'; BctThreadsReport.analz_thread_posts_of_users_rank1(2250212,HOURS_BACK) ##load thr-posts 
end
