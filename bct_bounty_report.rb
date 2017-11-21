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

    posts = DB[:posts].join(:threads, :tid=>:tid)
    .join(:users, :uid=>:posts__addeduid)
    .filter(fid:fid)
    .filter(Sequel.lit("posts.siteid=? and addeddate > ? and rank>2", SID, from))
    .select(:addeduid, :addedby).all

    res=[]
    res<<"top 25 users bounty from: #{from.strftime("%F %H:%M")} forum:#{title}"
    posts.group_by{|pp| pp[:addeduid]}.select{|uid,pp| user_bounties[uid]}
    .sort_by{|uid,pp| -unames[uid][1]}.each do |uid,uposts|
      res<<"[b]#{unames[uid][0]}[/b] (#{unames[uid][1]}) #{user_bounties[uid]}"
    end  

    fpath ="../report/users_bounties_#{fid.join('_')}.html"
    File.write(fpath, res.join("\n"))

  end   
  def self.print_grouped_by_bounty(fid, hours=24)

    title = DB[:forums].filter(siteid:SID,fid:fid).select_map(:title)
    p "report print_grouped_by_bounty forum:#{title}"
    from=DateTime.now.new_offset(0/24.0)-hours/24.0

    unames = DB[:users].filter(siteid:SID).to_hash(:uid, [:name,:rank])
    user_bounties = DB[:bct_user_bounty].to_hash(:uid, :bo_name)

    posts = DB[:posts].join(:threads, :tid=>:tid)
    .join(:users, :uid=>:posts__addeduid)
    .filter(fid:fid)
    .filter(Sequel.lit("posts.siteid=? and addeddate > ? and rank>2", SID, from))
    .select(:addeduid).all

    res=[]
    res<<"grouped by bounty  ***forum:#{title} for last #{hours} hours"
    users = posts.group_by{|pp| pp[:addeduid]}.select{|uid,b_uu| user_bounties[uid]}.map { |k,v| k }
    users.group_by{|uid| user_bounties[uid].gsub(' ', '')}.sort_by{|bname,uu| -uu.size}.each do |bname, uids|
      break if uids.size<2

      #res<<" -------"
      res<<" ---[b]#{bname}[/b] #{uids.size}"
      res<< uids.each_slice(5).to_a.map do |sub_uids| 
        sub_uids.map { |uid| "#{unames[uid][0]}(#{unames[uid][1]})"}.join(',')
      end

    end  
    fidd = fid.join('_') rescue fid

    fpath ="../report/grouped_bounties_#{fidd}.html"
    File.write(fpath, res.join("\n"))

  end        
end

#67 159
#BctReport.print_users_bounty([67,159])
#BctReport.print_grouped_by_bounty [67,159]