require_relative  'parsers/bct_parser'
require_relative  'parsers/bct_parser_adv'
require_relative  'cmd_helper'
require_relative  'bct_report'
require_relative  'parsers/helpers/bct_helper'

action = ARGV[0]
first = ARGV[1].to_i
second = ARGV[2].to_i
third = ARGV[3].to_i

##    159  Announcements (Altcoins)
##    240  Tokens (Altcoins)
##    52   Services
##    85   service discussion
##    67   altcoin discussion

##    238  bounty (Altcoins)
##    212   Micro Earnings
arr_forums=[159,240,67,85,52,238]
HOURS_BACK =12
fid = first

case action

##parser
when 'check_forums';    BCTalkParser.check_forums(fid) #pages_back
when 'selected';        BCTalkParser.check_selected_threads

when 'tstat';                 BCTalkParserAdv.load_thread_responses_to_stat_thread(fid, HOURS_BACK,1)
when 'tstat_posts';           BCTalkParserAdv.load_threads_with_max_responses_for_last12h(fid, HOURS_BACK)
when 'tstat_all';             BCTalkParserAdv.load_list_forums_pages_threads_responses_to_stat_thread(arr_forums, HOURS_BACK)
when 'tstat_rep';             BctReport.forum_threads_with_max_answers(fid, HOURS_BACK,'f') 
when 'tstat_all_rep';         BctReport.list_forum_threads_with_max_answers(arr_forums,HOURS_BACK,'f') 

when 'stat_threads_start_from_page';     BCTalkParser.load_one_forum_pages_threads_responses_to_stat_thread(fid,second,third)#fid start_page hours_back

when 'parse_forum';       BCTalkParser.parse_forum(fid,second,true) #if true #need_parse_forum(first,9)
when 'parse_forum_diff2'; BCTalkParser.set_opt({thread_posts_diff:2,rank:2}).parse_forum(fid,second,true) # fid page need_dowl

##report
when 'repf';            BctReport.gen_threads_with_stars_users(fid,'f', second) ##ruby bctalk.rb rep 159 f|t
when 'rept';            BctReport.gen_threads_with_stars_users(fid,'t', second) ##ruby bctalk.rb rep 159 f|t
when 'bounty';          BctReport.print_grouped_by_bounty(fid) 
when 'topu';            BctReport.top_active_users_for_forum(fid) ##ruby bctalk.rb topu 159
when 'thread_users';    BctReport.analyse_users_posts_for_thread(fid) 
when 'clean_err';       File.write('BCT_THREADS_ERRORS', '') 
when 'h';               p "1 bitcoin discussion 67 altcoins discussion, 159 Announcements (Altcoins) 72 форки 238 bounty (Altcoins)" 
  
when 'parse_thr'
  if true #need_parse_thread(first,9)
    second=1 if second==0
    BCTalkParserHelper.load_thread(first,second) #tid, pages_back
  end

end
