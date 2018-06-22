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


  def self.print_users_bounty

    from=DateTime.now.new_offset(0/24.0)-0.6

    unames = DB[:users].filter(siteid:SID).to_hash(:uid, [:name,:rank])
    user_bounties = DB[:bct_user_bounty].to_hash(:uid, :bo_name)

    res=[]

    user_bounties.sort_by{|uid, bname| -(unames[uid][1]||0)}.each do |uid,bname|
      if (unames[uid][1]||0)<2
        profile_link = "https://bitcointalk.org/index.php?action=profile;u=#{uid};sa=showPosts"
        #res<<"[b]#{unames[uid][0]} (#{unames[uid][1]}) [/b] #{bname}  #{profile_link}"
        res<<"[b]#{unames[uid][0]} (#{unames[uid][1]}) [/b] #{bname}"
      end
    end

    fpath ="report/users_bounties.html"
    File.write(fpath, res.join("\n"))

  end
  def self.print_grouped_by_bounty(hours=24)

    p "report print_grouped_by_bounty"
    from=DateTime.now.new_offset(0/24.0)-hours/24.0

    user_bounties = DB[:bct_user_bounty]
    .join(:users, :uid=>:bct_user_bounty__uid)
    .filter(Sequel.lit("rank>2"))
    .to_hash(:uid, [:bo_name, :rank])

    #user_bounties = DB[:bct_user_bounty].to_hash(:uid, :bo_name)

    res=[]
    res<<"[table]"

    #bounty_users = user_bounties.group_by{|uid,bb| uid}.map{|uid,v| [uid, v.last]}.to_h
    bounty_users = user_bounties.group_by{|k,v| v[0].gsub(' ', '')}.sort_by{|k,v| -v.size}

    ranks_names = [[3,'full_member'],[4,'sr_member'],[5,'hero'],[11,'legend']].to_h

    bounty_users.each do |bname, uids|
      next if uids.size<3

      #res<<" -------"
      ranks = uids.map { |k,v| v[1]}.sort_by{|r| r}
      grouped_ranks = ranks.group_by{|r| r}.map{|r, pp| "#{ranks_names[r]}-#{pp.size}"}.join(', ')

      res << "[tr] [td] [b]#{bname}[/b] [/td] [td] #{grouped_ranks} [/td][/tr]"
      #res<<"[b]#{bname}[/b]   " + uids.map { |k,v| "#{v[0]}(#{v[1]})"}.join(',')

    end
    res<<"[/table]"

    fpath ="report/grouped_bounties.html"
    File.write(fpath, res.join("\n"))

  end

  def self.print_changed_bounty(hours=24)

    p "report print_changed_bounty"
    from=DateTime.now.new_offset(0/24.0)-hours/24.0

    unames = DB[:users].filter(siteid:SID).to_hash(:uid, [:name,:rank])
    user_bounties = DB[:bct_user_bounty].select_map([:uid, :bo_name, :created_at])

    res=[]

    res<<"[table]"

    user_bounties
    .select{|uid, bname| (unames[uid][1]||0)>3}
    .group_by{|dd| dd[0]}
    .sort_by{|uid, list_bounty_name| -(unames[uid][1]||0)}
    .each do |uid, list_bounty_name|
      next if list_bounty_name.size <2
      bounty_names = list_bounty_name.map{|bb| "#{bb[1]}(#{bb[2].strftime("%F")})"}.join('  ')

      profile_link = "https://bitcointalk.org/index.php?action=profile;u=#{uid};sa=showPosts"
      #res<<"[b]#{unames[uid][0]} (#{unames[uid][1]}) [/b] #{bname}  #{profile_link}"
      res<<"[tr] [td] [b]#{unames[uid][0]} (#{unames[uid][1]}) [/b] [/td] [td] #{bounty_names} [/td][/tr]"

    end
    res<<"[/table]"

    fpath ="report/changed_bounties.html"
    File.write(fpath, res.join("\n"))

  end
  def self.print_changed_and_grouped(hours=24)

    p "report print_changed_bounty"
    from=DateTime.now.new_offset(0/24.0)-hours/24.0

    unames = DB[:users].filter(siteid:SID).to_hash(:uid, [:name,:rank])
    user_bounties = DB[:bct_user_bounty].select_map([:uid, :bo_name, :created_at])

    res=[]
    ranks_names = [[3,'full_member'],[4,'sr_member'],[5,'hero'],[11,'legend']].to_h

    bounty_and_users = Hash.new {|h,k| h[k] = [] } #Hash.new([])

    user_bounties
    .select{|uid, bname| (unames[uid][1]||0)>3}
    .group_by{|dd| dd[0]}
    .sort_by{|uid, list_bounty_name| -(unames[uid][1]||0)}
    .each do |uid, list_bounty_name|
      next if list_bounty_name.size <2

      last_bounty = list_bounty_name.last[1]
      bounty_names = list_bounty_name.map{|bb| "#{bb[1]}(#{bb[2].strftime("%F")})"}.join('  ')
      bounty_and_users[last_bounty] << {uid: uid, bounty_names: bounty_names}

    end
    
    bounty_and_users
    .sort_by{|bname, users| -users.size }.each do |last_bounty, users_array|
      next if users_array.size <3

      res<<" ------------------[b]#{last_bounty}[/b]"
      
      users_array.each do |user|
        uid = user[:uid]
        bounty_names = user[:bounty_names]
        res<<"[b]#{unames[uid][0]} [/b](#{ranks_names[unames[uid][1]]})  || #{bounty_names}"
      end
    end


    fpath ="report/changed_bounties.html"
    File.write(fpath, res.join("\n"))

  end
end

#67 159
#BctReport.print_users_bounty([67,159])
#BctReport.print_grouped_by_bounty [67,159]
