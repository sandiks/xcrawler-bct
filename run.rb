require 'rufus-scheduler'

require_relative  'parsers/bct_parser_adv'
require_relative  'parsers/bct_parser'

require_relative  'bct_users_report'
require_relative  'bct_threads_report'

FORUMS=[159,240,52,85,238]
HOURS_BACK=24


def stat(fid)

  hours=12
  BCTalkParserAdv.save_thread_responses_statistics(fid, hours)
  BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(fid,hours)
  #BCTalkParserAdv.calc_reliable_for_forum(fid)
  BctThreadsReport.report_response_statistic(fid,hours,true)
end

def job
  BCTalkParserAdv.save_thread_responses_statistics_FOR_LIST_FORUMS(FORUMS, HOURS_BACK) ##ruby bctalk_stat.rb stat_all

  #BCTalkParserAdv.load_posts_for_max_responses_threads_in_interval(159,HOURS_BACK) ##   ruby bctalk_stat.rb load_posts_sorted_max 159
  #BctThreadsReport.report_response_statistic_LIST_FORUMS(FORUMS,HOURS_BACK)
end

def load_thread_and_report_post
  tid=2384512
  BCTalkParserAdv.load_thread_before_date(159,2384512,240)
  BctThreadsReport.analz_thread_posts_of_users(tid,120)
end


##  generate report with thread name and users with rank>3
def load_post_and_gen_report
  fid=8
  pg=1
  hours=24

  BCTalkParser.set_from_date(hours).parse_forum(fid,pg,true)
  #BctUsersReport.gen_threads_with_stars_users(fid, hours)
end
#load_post_and_gen_report

def run(p1)
  scheduler = Rufus::Scheduler.new
  scheduler.every "#{p1}m" do
    p "started #{DateTime.now.strftime("%k:%M:%S")}"
    BCTalkParserAdv.save_thread_responses_statistics(FORUMS, HOURS_BACK)
  end

  scheduler.join
end

DB = Repo.get_db
def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

def set_unreliable(tid)
  #tid=2423910
  fid=DB[:threads].first(tid:tid)[:fid]
  DB[:threads_attr].insert({fid:fid,tid:tid,reliable:0, modified: date_now(0)})

end

fid = ARGV[1].to_i
hours = ARGV[2].to_i

case ARGV[0]
when 'stat'; stat(fid)
when 'job'; job
when 'calc'; BCTalkParserAdv.calc_reliable_for_forum(fid)

when 'rep'; BctThreadsReport.report_response_statistic(fid,hours,true)
when 'thread'; BCTalkParserAdv.load_thread_before_date(fid,tid,hours)
when 'set_unreliable'; set_unreliable(ARGV[1].to_i)
end


#p BCTalkParser.parse_thread_page(2398403,12)
