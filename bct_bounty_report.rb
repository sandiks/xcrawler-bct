require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true


class BctBountyReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end
  


################## ----------------------------------


  def self.print_users_bounty(fid)

    title = DB[:forums].filter(siteid:SID,fid:fid).select_map(:title)
    from=DateTime.now.new_offset(0/24.0)-0.6

    unames = DB[:users].filter(siteid:SID).to_hash(:uid, [:name,:rank])
    user_bounties = DB[:bct_user_bounty].to_hash(:uid, :bo_name)

    res=[]

    user_bounties.sort_by{|uid, bname| -unames[uid][1]}.each do |uid,bname|
      res<<"[b]#{unames[uid][0]} (#{unames[uid][1]}) [/b] #{bname}" if unames[uid][1]>2
    end  

    fpath ="report/users_bounties_#{fid}.html"
    File.write(fpath, res.join("\n"))

  end   
  def self.print_grouped_by_bounty(fid, hours=24)

    title = DB[:forums].filter(siteid:SID,fid:fid).select_map(:title)
    p "report print_grouped_by_bounty forum:#{title}"
    from=DateTime.now.new_offset(0/24.0)-hours/24.0

    user_bounties = DB[:users].filter(siteid:SID)
    .join(:bct_user_bounty, :uid=>:users__uid)
    .to_hash(:uid, [:name,:rank,:bo_name])

    #user_bounties = DB[:bct_user_bounty].to_hash(:uid, :bo_name)

    res=[]
    res<<"grouped by bounty  ***forum:#{title} for last #{hours} hours"

    bounty_users = user_bounties.select{|k,v| v[1]>2}.group_by{|k,v| v[2].gsub(' ', '')}

    #sort_by{|k,v| -v[1]}
    bounty_users.each do |bname, uids|
      #break if uids.size<2

      #res<<" -------"
      #p " ---[b]#{bname}[/b] #{uids.size}"
      res<<"[b]#{bname}[/b]   " + uids.map { |k,v| "#{v[0]}(#{v[1]})"}.join(',')

    end  
    fidd = fid.join('_') rescue fid

    fpath ="report/grouped_bounties_#{fidd}.html"
    File.write(fpath, res.join("\n"))

  end        
end

#67 159
#BctReport.print_users_bounty([67,159])
#BctReport.print_grouped_by_bounty [67,159]