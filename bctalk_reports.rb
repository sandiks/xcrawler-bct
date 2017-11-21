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

##report
when 'repf';            BctReport.gen_threads_with_stars_users(fid,'f', second) ##ruby bctalk.rb rep 159 f|t
when 'rept';            BctReport.gen_threads_with_stars_users(fid,'t', second) ##ruby bctalk.rb rep 159 f|t
when 'bounty';          BctReport.print_grouped_by_bounty(fid) 
when 'topu';            BctReport.top_active_users_for_forum(fid) ##ruby bctalk.rb topu 159
when 'thread_users';    BctReport.analyse_users_posts_for_thread(fid) 
when 'h';               p "1 bitcoin discussion 67 altcoins discussion, 159 Announcements (Altcoins) 72 форки 238 bounty (Altcoins)" 

end
