require_relative  'bct_users_report'
require_relative  'bct_bounty_report'

##    159   Announcements (Altcoins)
##    240   Tokens (Altcoins)
##    238   bounty (Altcoins)

##    52    Services
##    84    Service Announcements
##    85    Service Discussion
##    197   Service Announcements (Altcoins)
##    198   Service Discussion (Altcoins)
##    67    altcoin discussion
##    212   Micro Earnings
##    1     Bitcoin Discussion
##    72     Альтернативные криптовалюты


#select uid, count(uid) from bct_user_bounty group by uid having count(uid)>1
def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

def merit
#select uid, count(uid) from user_merits group by uid having count(uid)>1

  hours=24*5
  #BCTalkParserAdv.save_thread_responses_statistics(fid, hours)
  BctUsersReport.report_users_sorted_by_merit_for_day(hours) 
end

#########
DB = Repo.get_db


def clean_table
  from=date_now(24*45)
  p DB[:bct_user_bounty].where{created_at<from}.delete
end


fid = ARGV[1].to_i
hours = ARGV[2].to_i

case ARGV[0]

  when 'bounty'; BctBountyReport.print_grouped_by_bounty
  when 'changed'; BctBountyReport.print_changed_bounty
  when 'changed2'; BctBountyReport.print_changed_and_grouped

  when 'merit'; merit
  when 'clean_table'; clean_table

end