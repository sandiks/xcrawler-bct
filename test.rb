require_relative  'helpers/helper'
require_relative  'helpers/repo'
require_relative  'helpers/page_utils'
require_relative  'parsers/bct_parser_adv'


DB = Repo.get_db

def date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end

THREADS_ANALZ_NUM=15
SID=9
FID=159
TID=1847292
HOURS_BACK=24

def test_select_map
  fid=159
  threads_num=80
  from=date_now(8*24)

  threads_responses = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ?",fid, from))
    .select_map([:tid,:responses,:last_post_date])
  
  p sorted_thread_stats = threads_responses.group_by{|dd| dd[0]}
    .select{ |k,v| v.size>1 && v.all?{|tt| tt[1] <300 } }
    .map{ |tid, vv| dd=vv.map{ |el| el[1]  }.minmax;  [tid, dd.last-dd.first] }
    .sort_by{ |tid_resp| -tid_resp[1] }
    .take(threads_num)

end
test_select_map

def show_responses_and_ranks_for_thread(fid,tid)
  from=date_now(HOURS_BACK)
  show_ranks=true

  ##-----------------------
  p "from #{from.strftime("%F %k:%M ")}"
  threads_titles = DB[:threads].filter(fid:fid).to_hash(:tid, :title)


  forum_stat = DB[:forums_stat].filter(Sequel.lit("fid=? and bot_parsed > ?",fid, from))
  .select_map(:bot_parsed)

  parsed_forum_date_min = forum_stat.min.to_datetime
  p "parsed_forum_date_min #{parsed_forum_date_min.strftime("%F %k:%M ")}"

  ##--------
  threads_stat = DB[:threads_responses].filter(Sequel.lit("fid=? and last_post_date > ?",fid, parsed_forum_date_min))
  .select_map([:tid,:responses,:last_post_date])


  p max_resps_threads = threads_stat.group_by{|h| h[0]}
  .select{|k,v| k==tid}
  .sort_by{|k,tt| dd=tt.map { |el| el[1]  }.minmax; dd[1]-dd[0] }
  .reverse.take(THREADS_ANALZ_NUM)

  out=[]
  max_resps_threads.each do |tid, tt|

    #p tpages = DB[:tpages].filter(Sequel.lit("tid=?", tid)).to_hash(:page,[:postcount])


    if show_ranks
      ranks = DB[:posts].filter( Sequel.lit("tid=? and addeddate > ?", tid, parsed_forum_date_min) )
      .order(:addeddate).select_map(:addedrank)

      ranks_gr = ranks.group_by{|x| (x||1)}.map { |k,v| [k,v.size]}.to_h
      rank_info = [1,2,3,4,5,11].map{|x|  "#{x==11? 'legend': ('rank(%s)' % x)}-#{ranks_gr[x]||0} "}.join(' ')
    end

    p  resps_minmax=tt.map { |el| el[1]  }.minmax

    page_and_num = PageUtil.calc_last_page(resps_minmax[1]+1,20)
    lpage = (page_and_num[0]-1)*40 rescue 0
    url = "https://bitcointalk.org/index.php?topic=#{tid}.#{lpage}"
    out<< "responses: #{ resps_minmax[1]-resps_minmax[0]} "
    out<< "#{rank_info}" if show_ranks
    out<< "#{url}    #{threads_titles[tid]}"
    out<< ""
  end
  puts out
end


def thread_posts_stats(tid,hours_back=24) ## for site, show when you click 'post' button

  from = date_now(hours_back)

  responses =  DB[:threads].first(tid:tid)[:responses]


  page_and_num = PageUtil.calc_last_page(responses+1,20)
  lpage = page_and_num[0]
  lcount = page_and_num[1]
  p "---thread_stats tid:#{tid} responses: #{responses} last #{page_and_num}"

  url_templ = "https://bitcointalk.org/index.php?topic=%s.%s"
  url = url_templ % [tid,(lpage-1)*40]

  tpages = DB[:tpage_ranks].filter(Sequel.lit("tid=?", tid)).to_hash(:page,[:postcount,:fp_date,:r1,:r2,:r3,:r4,:r5,:r11]).first(20)

  all_ranks = [0,0,0,0,0,0,0]

  tpages.sort_by{|k,v| -k}.each do |pp,data|
    p pp
    p ranks = data[2..7]
    6.times{|ind| all_ranks[ind+1]+=ranks[ind]}
    break if data[1].to_datetime<from
  end

  p all_ranks
  sum = all_ranks.sum*10
  points = all_ranks[1]+all_ranks[2]+all_ranks[3]*2+all_ranks[4]*2+all_ranks[5]*2+all_ranks[6]
  reliable = points/sum.to_f

  p "sum #{sum} reliable #{reliable}"

end

def test_last_parsed_date_and_current_date
  fid = 240
  now = date_now(0)

  parsed_dates = DB[:forums_stat].filter(fid:fid).reverse_order(:bot_parsed).limit(2).select_map(:bot_parsed)
  last_parsed_date =  parsed_dates.last.to_datetime
  #p now-last_parsed_date
  diff =  (now.to_time - last_parsed_date.to_time) / 3_600
  p diff.round
end

def parse_signature
  rank=2
  sign_tr = File.open("signature.html") { |f| Nokogiri::HTML(f) }

  if rank>1 && sign_tr && (links = sign_tr.css('a'))
    
    #p links.map { |ll| ll['href'].gsub(' ','').strip  }

    grouped_domains = links.group_by do |ll|
      link = ll['href'].gsub(' ','').strip
      begin
        url = URI.parse( link ).host.split('.').last(2).join('.')
        if ['bitcointalk.org','goo.gl'].include?(url)
          url = link.sub(/^https?\:\/\/(www.)?/,'')
        end
        url
      rescue
        dmn = link.sub(/^https?\:\/\/(www.)?/,'').split('/').first
        dmn ? dmn.strip : "bitcointalk.org/error"
      end
    end

    domains = grouped_domains
    .sort_by{|k,v| ['bit.ly','goo.gl','www','bitcointalk.org'].include?(k) ? 0 : -v.size}
    .map { |k,v| v.size>1 ? k : v.map{ |ll| ll['href'].sub(/^https?\:\/\/(www.)?/,'') }.join('|') }
    
    p domains

    p kk = domains.first
    #p "bounty:  #{kk}".ljust(60)+"#{addedby}"
    p {uid:addeduid, bo_name:kk} 

  end
end

def test_load_posts_for_max_responses_thread(fid, tid, hours_back =24, threads_num=80)

  from=date_now(hours_back)
  to=date_now(0)

  tid_list = [tid]

  only_3_Pages = threads_num>30
  indx=0

  tid_list.each do |tid,resps_diff|

    #next if tid!=2675213
    indx+=1;
    p "--[#{indx}] tid: #{tid} resp_diff: #{resps_diff}"

    dd = BCTalkParserAdv.load_thread_pages_before_date(fid,tid, hours_back, 0, only_3_Pages)
    #sleep(1)

  end

  ##
  #Repo.insert_users(users_store.values, SID)

  #inserted_bounties = Repo.save_user_bounty(users_bounty.values, SID)
  #inserted_merits_users = Repo.insert_into_user_merits(BCTalkParserAdv.users_merit_store)


  tid_list.map { |e| e[0]  }

end

#test_load_posts_for_max_responses_thread(240,4553607)