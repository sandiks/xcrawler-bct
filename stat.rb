require 'rufus-scheduler'

require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'
require_relative  'bct_threads_report'


def run(p1)
  p "---start bot period:#{p1}m"
  scheduler = Rufus::Scheduler.new

  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(FORUMS, HOURS_BACK)
  end

  scheduler.join
end

FORUMS=[159,240,238,67,52,1]
#FORUMS=[67,52,1]
fid = ARGV[1].to_i
HOURS_BACK=12

downl_rank=1

case ARGV[0]
  when 'scheduler';             run(30)
  when 'stat';                  BCTalkParserAdv.load_thread_responses_to_stat_thread(fid, HOURS_BACK,1)
  when 'stat_all';              BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(FORUMS, HOURS_BACK)
  when 'stat_rep';              BctThreadsReport.forum_threads_with_max_answers(fid, HOURS_BACK,true) 
  when 'stat_all_rep';          BctThreadsReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK) 
  when 'load_posts';            BCTalkParserAdv.load_only_top10_post_in_thread(ARGV[1].to_i,downl_rank) 
  when 'load_posts_sorted_max'; BCTalkParserAdv.load_thread_posts_with_max_responses_in_interval(fid,HOURS_BACK) ##load thr-posts 
  when 'analz_thread_posts_of_users_rank1'; BctThreadsReport.analz_thread_posts_of_users_rank1(2250212,HOURS_BACK) ##load thr-posts 
  when 'tpage';                 BCTalkParser.parse_thread_page(2415495,ARGV[1].to_i) 
end
