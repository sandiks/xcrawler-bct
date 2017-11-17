require 'rufus-scheduler'

require_relative  'parsers/bct_parser_adv'
require_relative  'bct_report'

HOURS_BACK=12
fid = ARGV[1].to_i

#FORUMS=[159,240,67,52,1]
FORUMS=[67,52,1]

def run(p1)
  p "---start bot period:#{p1}m"
  scheduler = Rufus::Scheduler.new

  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(FORUMS, HOURS_BACK)
  end

  scheduler.join
end

case ARGV[0]
  when 'run';                   run(30)
  when 'tstat';                 BCTalkParserAdv.load_thread_responses_to_stat_thread(fid, HOURS_BACK,1)
  when 'tstat_all';             BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(FORUMS, HOURS_BACK)
  when 'tstat_rep';             BctReport.forum_threads_with_max_answers(fid, HOURS_BACK,'f') 
  when 'tstat_all_rep';         BctReport.list_forum_threads_with_max_answers(FORUMS,HOURS_BACK,'f') 
end
