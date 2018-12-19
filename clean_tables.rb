require_relative  'helpers/repo'


DB = Repo.get_db

def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

fid=159
from = date_now(24*5)

p "clean tables [threads_responses, bct_user_bounty]"

#p DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date < ?", fid, from)).delete
#p DB[:bct_user_bounty].filter(Sequel.lit("created_at < ?", date_now(24*30))).delete

####