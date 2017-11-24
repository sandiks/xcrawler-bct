require 'rufus-scheduler'

require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'

require_relative  'bct_users_report'
require_relative  'bct_threads_report'

FORUMS=[159,240]
HOURS_BACK=24



###stat
def stat
    fid=159
    hours=12
    BCTalkParserAdv.save_thread_responses_statistics(fid, hours)
    BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid,hours)
    BctThreadsReport.report_response_statistic(fid,hours)  
end

def job
  BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(FORUMS, HOURS_BACK) ##ruby bctalk_stat.rb stat_all

  BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(159,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 159
  BCTalkParserAdv.load_max_responses_threads_posts_in_interval(240,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 240

  #BctThreadsReport.show_response_statistic_for_forum_threads(fid, HOURS_BACK,true)
  BctThreadsReport.report_response_statistic_LIST_FORUMS(FORUMS,HOURS_BACK)
end


##  generate report with thread name and users with rank>3
def load_post_and_gen_report
    fid=8
    pg=1
    hours=24

    BCTalkParser.set_from_date(hours).parse_forum(fid,pg,true)
    #BctUsersReport.gen_threads_with_stars_users(fid, hours)
end
#p BCTalkParser.parse_thread_page(2398403,12)


def run(p1)
  scheduler = Rufus::Scheduler.new
  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.save_thread_responses_statistics(FORUMS, HOURS_BACK)
  end

  scheduler.join
end

case ARGV[0]
  when 'stat'; stat 
  when 'job'; job 
  when 'stat'; stat
end 