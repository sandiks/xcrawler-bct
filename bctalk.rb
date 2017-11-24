require_relative  'parsers/bct_parser'
require_relative  'parsers/bct_parser_adv'
require_relative  'helpers/cmd_helper'
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

when 'check_forums';    BCTalkParser.check_forums(fid) #pages_back
when 'selected';        BCTalkParser.check_selected_threads
when 'parse_forum';       BCTalkParser.parse_forum(fid,second,true) #if true #need_parse_forum(first,9)
when 'parse_forum_diff2'; BCTalkParser.set_opt({thread_posts_diff:2,rank:2}).parse_forum(fid,second,true) # fid page need_dowl
  
when 'parse_thr'
  if true #need_parse_thread(first,9)
    second=1 if second==0
    BCTalkParserHelper.load_thread(first,second) #tid, pages_back
  end

end
p BCTalkParser.parse_thread_page(2398403,12)