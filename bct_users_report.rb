require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'

Sequel.split_symbols = true


class BctUsersReport
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20

  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end
  

  def self.report_users_sorted_by_merit_for_day(hours_back =24)

    p "---------report_users_sorted_bymerit_for_day  --hours_back:#{hours_back}"

    from = date_now(hours_back)
    to   = date_now(0)

    user_names = DB[:users].to_hash(:uid, :name)

    ##generate
    out = []

    is_forum = true
    bold =  is_forum ? "[b]" : "**"
    bold_end = is_forum ? "[/b]" : "**"

    out<< ""
    out<< ""
    out<<"#{bold}#{from.strftime("%F %H:%M")}  -  #{to.strftime("%F %H:%M")}#{bold_end}"
    out<<"------------"

    indx=0

    user_merits = DB[:user_merits].filter(Sequel.lit("date > ?", from))
    .select_map([:uid,:merit,:date])

    sorted_user_merits = user_merits.group_by{|dd| dd[0]}
    .select{|k,v| v.size>1}
    .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax;  dd.last-dd.first }
    .reverse.take(30)

    sorted_user_merits = sorted_user_merits
    .map{|k,vv| dd=vv.map { |el| el[1]  }.minmax;  [k, dd.last-dd.first, dd.last] }

    sorted_user_merits.each do |uid, diff_merit, last_merit|
    
      indx+=1
    
      out<< " #{user_names[uid]}(#{uid}) merits: #{last_merit} +merits #{diff_merit}"
      out<<""
    end

    File.write("report/report_user_mertits.html", out.join("\n"))

  end

################## ----------------------------------
  def self.gen_threads_with_stars_users(fid, hours =12)
    type='f'
    rank=2
    time=6 if time==0
    
    from = date_now(hours)
    to =   date_now(0)

    title = DB[:forums].filter(fid:fid).first[:title] rescue "no forum"
    uranks = DB[:users].to_hash(:name, :rank)
    threads = DB[:threads].filter(fid:fid).to_hash(:tid, :title)
    threads_responses = DB[:threads].filter(fid:fid).to_hash(:tid, :responses)

    posts = DB[:posts].join(:threads, :tid=>:tid)
    .filter(Sequel.lit("threads.fid=? and addeddate > ? and addeddate < ? and addedrank>=?", fid, from, to,rank))
    .order(:addeddate)
    .select(:addeduid, :addedby, :addeddate, :posts__tid, :addedrank).all

    p "forum:#{title} posts:#{posts.size}"

    ##generate
    is_forum = type =='f' 
    bold =  is_forum ? "[b]" : "**"
    bold_end = is_forum ? "[/b]" : "**"


    out = []
    
    is_forum ? out<<"#{bold}forum: #{title}#{bold_end}" : out<<"Most active(for #{time} hours) threads from \"#{bold}#{title}#{bold_end}\""
    out<<"#{bold}#{from.strftime("%F %H:%M")}  -  #{to.strftime("%F %H:%M")}#{bold_end}"
    out<<"------------"
    
    idx=0
    #posts.group_by{|h| h[:tid]}.sort_by{|k,v| -v.inject(0) { |sum, p| sum+(uranks[p[:addedby]]||0) } }.take(25).each do |tid, posts| 
    posts.group_by{|h| h[:tid]}.sort_by{|k,pp| -pp.size }.take(25).each do |tid, th_posts| 
            thr_title = threads[tid]||tid
            resps = threads_responses[tid]||0
            page_and_num = PageUtil.calc_last_page(resps+1,20)
            lpage = (page_and_num[0]-1)*20 rescue 0
            
            url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"

            posts = is_forum ? "" : "(#{th_posts.size} сообщ)"

            out<<"#{bold}#{idx+=1} #{thr_title}#{bold_end} #{url} #{posts}"
            if is_forum
              th_posts.group_by{|pp| [pp[:addedby],pp[:addedrank]]}.sort_by{|k,pp| -k[1]}.each  do |key,uposts|
                ss = uposts.size
                out<<"#{bold}#{key[0]} (#{print_rank(key[1])})#{bold_end} [#{ss>1 ? ss.to_s+' posts' : '1 post'}]"
              end if is_forum
            else
              count = th_posts.size
              dd = [11,5,4,3].map { |rr|  th_posts.count{|pp| pp[:addedrank]==rr} }
              #out<< "count:#{count}   legend #{dd[0]},  5-stars #{dd[1]},  4-stars #{dd[2]},  3-stars #{dd[3]}"  
            end

            out<<"------------" #if is_forum
        
    end

    if false #is_forum  #active users
      top = 25

      posts = DB[:posts].join(:threads, :tid=>:tid)
      .filter(Sequel.lit("threads.fid=? and addeddate > ?", fid, from)).select(:addeduid, :addedby).all

      out<<"**top #{top} active users** from:#{from.strftime("%F %H:%M")}"
      posts.group_by{|pp| pp[:addedby]}.sort_by{|uname,pp| -pp.size}.take(top).each  do |uname,uposts|
        out<<"#{bold}#{uname}#{bold_end} (#{uranks[uname]}) posts:#{uposts.size}"
      end
    end 

    rep_name = is_forum ? "for_rep" : "teleg_rep" 

    fpath ="report/#{rep_name}_#{fid}.html"
    File.write(fpath, out.join("\n"))
    #system "chromium '#{fpath}'"

  end
  
  def self.print_rank(rank)
    rank==11 ? "**legend**" : "#{rank}"
  end

  def self.analyse_users_posts_for_thread(tid)

    from=DateTime.now.new_offset(0/24.0)-1
    uranks = DB[:users].to_hash(:name, :rank)

    posts = DB[:posts].join(:users, :uid=>:posts__addeduid)
    .filter(Sequel.lit("tid=? and rank>3 and addeddate > ?", tid, from)).select(:addeduid, :addedby, :addeddate, :body).all

    res=[]
    posts.group_by{|pp| pp[:addedby]}.each  do |uname,uposts|
      times = uposts.map { |pp|  "[#{pp[:addeddate].strftime("%m-%d %H:%M")} words:#{pp[:body].split.size}]"}.join(", ")
      res<<"[b]#{uname}[/b] (#{uranks[uname]}) #{times}"
    end  

    puts res

  end
  
  def self.top_active_users_for_forum(fid)

    title = DB[:forums].filter(fid:fid).first[:title]
    from=DateTime.now.new_offset(0/24.0)-1
    uranks = DB[:users].to_hash(:name, :rank)

    posts = DB[:posts].join(:threads, :tid=>:tid).join(:users, :uid=>:posts__addeduid)
    .filter(Sequel.lit("threads.fid=? and addeddate > ?", fid, from)).select(:addeduid, :addedby).all

    res=[]
    res<<"most active users from: #{from.strftime("%F %H:%M")} forum:#{title}"
    posts.group_by{|pp| pp[:addedby]}.sort_by{|uname,pp| -pp.size}.each  do |uname,uposts|
      res<<"[b]#{uname}[/b] (#{uranks[uname]}) posts:#{uposts.size}"
    end  

    fpath =File.dirname(__FILE__) + "/topu#{fid}.html"
    File.write(fpath, res.join("\n"))

    puts res

  end

end
