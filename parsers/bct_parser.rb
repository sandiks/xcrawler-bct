require 'nokogiri'
require 'open-uri'
require 'parallel'
require_relative  '../helpers/helper'
require_relative  '../helpers/repo'
require_relative  '../helpers/page_utils'

#Powered by SMF 1.1.19

class BCTalkParser
  DB = Repo.get_db
  SID = 9
  THREAD_PAGE_SIZE =20

  @@need_save= true
  @@log =[]
  @@from_date = DateTime.now.new_offset(0/24.0)
  @@fid=0

  @@options={}

  #def self.check_selected_threads; BCTalkParserHelper.check_selected_threads; end
  def self.set_opt(opts={}); @@options = opts; return self; end
  def self.date_now(hours=0); DateTime.now.new_offset(0/24.0)-hours/24.0; end
  
  def self.from_date
      @@from_date
  end

  def self.check_forums(pages_back=1, need_parse_threads=false)
    forums = DB[:forums].filter(siteid:SID, check:1).map(:fid)

    Parallel.map(forums,:in_threads=>3) do |fid|
      #forums.each do |fid|
      parse_forum(fid, 1, need_parse_threads)
      #1.upto(pages_back) {|pg| parse_forum(fid, pg) }
    end

  end

  def self.parse_forum(fid, pg=1, downl_threads=false)

    @@fid=fid
    pp = (pg>1 ? "#{(pg-1)*40}" : "0")
    link = "https://bitcointalk.org/index.php?board=#{fid}.#{pp}"

    page = Nokogiri::HTML(download_page(link))
    #page = Nokogiri::HTML(File.open("btctalk128.html"))

    threads = page.css("div.tborder table tr")

    page_threads =[]

    threads.each_with_index do |tr,indx|
      next if tr.css("td").size != 7

      thr_a = tr.css("td:nth-child(3)  a")[0]
      thr_title = thr_a.text
      thr_link = thr_a['href']
      tid = thr_link.split('=').last.scan(/\d+/)[0].to_i
      date = tr.css("td:nth-child(7) span").text.strip
      date_str = date[0..date.index('by')-1].strip
      date = parse_post_date(date_str)

      page_threads << {
        fid:fid,
        tid:tid,
        title:thr_title,
        responses: tr.css("td")[4].text.to_i,
        viewers: tr.css("td")[5].text.to_i,
        updated: date,
        siteid:SID,
      }
    end

    #page_threads.each_with_index { |tt, ind| p  "#{ind} #{tt[:title]} || #{tt[:updated]}"  }
    ##save statistics 
    inserted=Repo.insert_into_threads_responses(SID, fid, page_threads)

    last_date =page_threads.last[:updated]
    p "[parse_forum] fid:#{fid}  pg:#{pg} last_date:#{last_date.strftime('%F %H:%M:%S')} inserted:#{inserted}"
        
    Repo.insert_or_update_threads_for_forum(page_threads,SID) if @@need_save

    if downl_threads
      old_thread_resps = DB[:threads].filter(siteid:SID, fid: fid).to_hash(:tid,:responses)
      load_forumPage_threads(fid, page_threads, old_thread_resps)
    end

    return nil if inserted ==0 
    return last_date
  end

  def self.load_forumPage_threads(fid, page_threads, old_thread_resps)
  
    Parallel.map_with_index(page_threads,:in_threads=>2) do |thr,idx|
    #page_threads.each do |thr|
      tid = thr[:tid]

      #next if tid!=2047476

      responses = thr[:responses]
      page_and_num = PageUtil.calc_last_page(responses+1,20)
      lpage = page_and_num[0]
      lcount = page_and_num[1]

      #old_resps = old_thread_resps[tid]

##calc how many pages_back neeed download for current thread 
      downl_pages=calc_arr_downl_pages(tid,lpage,lcount,@@from_date).take(3)

      res=[]
      stars=0
      downl_pages.each do |pp|   
        res<<pp[0]
        
        loop do
          begin
            ## load page with post for [tid,pg]
            data = parse_thread_page(tid, pp[0]) 
            stars += data[:stars]||0
            break
          rescue  =>ex 
            puts "#{idx} !!!load_forum_threads [#{tid}.#{pp[0]}] #{ex.class} "
            #File.open('BCT_THREADS_ERRORS', 'a') { |f| f.write("#{tid} #{pp[0]}\n") }
            sleep 2 
          end
        end

      end      
      planned_str=downl_pages.map { |pp| "<#{pp[0]}*#{pp[1]} #{ pp[2] ? pp[2].strftime('%d**%H:%M:%S') : 'nil'}>" }.join(', ')

      p "[#{idx} load_thr #{tid} last:#{page_and_num}".ljust(40)+
      "upd: #{thr[:updated].strftime("%d**%H:%M:%S") }]".ljust(20)+
      "planned:#{planned_str.ljust(40)}  down:#{res} stars:#{stars}" if downl_pages.size>0
    end

    page_threads.last[:updated] #return last thread updated date

  end

  def self.get_diff
     dd = {72=> 3, 159=>3, 90=>2}
     dd[@@fid]||2
  end

  def self.calc_arr_downl_pages(tid, lp_num, lp_post_count, start_date)
    downl_pages=[]

    tpages = DB[:tpages].filter(Sequel.lit("siteid=? and tid=?", SID, tid)).to_hash(:page,[:postcount,:fp_date])
    
    #last thread page
    need_downl_preLast_pages=true

    mc0=0
    if tpages[lp_num]
      mc0=tpages[lp_num][0]
      first_postdate = tpages[lp_num][1]
      need_downl_preLast_pages = first_postdate && first_postdate.to_datetime> start_date
    end
    downl_pages<<[lp_num,mc0, first_postdate] if lp_post_count-mc0>=  (@@options[:thread_posts_diff]||get_diff)

    #added pre-last pages
    if need_downl_preLast_pages

      (lp_num-1).downto(lp_num-30) do |pg|
        break if pg<1
        mc=0
        lp_date=nil
        if tpages[pg]
          mc =  tpages[pg][0]
          lp_date = tpages[pg][1]
          date_is_out = lp_date && lp_date.to_datetime< start_date
        end

        downl_pages<<[pg, mc, lp_date] if mc!=THREAD_PAGE_SIZE 
        break if date_is_out
      end
    end

    downl_pages
  end
  
  def self.get_link(tid, page=1)
    pp = (page>1 ? "#{(page-1)*THREAD_PAGE_SIZE}" : "0")
    link = "https://bitcointalk.org/index.php?topic=#{tid}.#{pp}"
  end

  def self.parse_thread_page(tid, page=1)
    return if page<1
    
    link = get_link(tid,page)
    fname = "html/bctalk-tid#{tid}-p#{page}.html"
    page_html = Nokogiri::HTML(download_page(link))
    
    #File.write(fname, page_html)
    #page_html = Nokogiri::HTML(File.open(fname)) if File.exist?(fname)

    parse_thread_from_html(tid, page, page_html)
  end

  def self.parse_thread_from_html(tid, page, page_html)

    post_class = page_html.css("div#bodyarea > form > table.bordercolor tr").first.attr('class')
    top_mid = page_html.css("div#bodyarea > a")[1]
    top_mid = top_mid['name']

    thread_posts = page_html.css("div#bodyarea > form > table.bordercolor tr[class^='#{post_class}']")

    posts =[]
    users={}
    bounties={}
    user_bounty={}
    idx =0

    ##parse posts
    thread_posts.map do |post|

      mid = post.css('a').first.attr('name')
      ##set top mid
      mid =top_mid unless mid
      mid = mid.sub('msg','').to_i


      post_tr = post.css('table tr > td > table > tr').first #td[class~="windowbg windowbg2"]
      sign_tr = post.css('table  tr > td > table >  tr div.signature').first

      td1=post_tr.css('td')[0]
      td2=post_tr.css('td')[1]

      #user info
      rank=0
      addeduid=0
      if td1
        link = td1.css('a')[0]
        url = link["href"]
        addedby = link.text.strip
        activity= td1.text.strip.scan(/Activity:\s+\d+/).join().sub('Activity:','').to_i
        addeduid = url.split('=').last.to_i
        rank = detect_user_rank(td1)

        unless users.has_key?(addeduid)
          users[addeduid]={siteid:SID, uid: addeduid, name:addedby, rank:rank}
        end
      end

      #parse signature
      if @@options[:parse_signature] && sign_tr && (links = sign_tr.css('a'))

        grouped_domains = links.group_by do |ll|
          link = ll['href'].gsub(' ','').strip
          begin
            URI.parse( link ).host.split('.').last(2).join('.') 
          rescue
            dmn = link.sub(/^https?\:\/\/(www.)?/,'').split('/').first
            dmn ? dmn.strip : "bitcointalk.org/error"
          end
        end

        domains = grouped_domains
        .sort_by{|k,v| k.include?("bitcointalk.org") ? 0 : -v.size}
        .map { |k,v| v.size>1 ? k : v.map{ |ll| ll['href'].sub(/^https?\:\/\/(www.)?/,'') }.join('|') }
        
        kk = domains.first
        #p "bounty:  #{kk}".ljust(60)+"#{addedby}"
        
        if kk && !kk.strip.empty? 
          bounties[kk] = { name:kk, descr: domains.join('|')} if !bounties.has_key?(kk) 
          user_bounty[addeduid] = {uid:addeduid, bo_name:kk} if !user_bounty.has_key?(addeduid)
        end
      end


      post_date_str = td2.css('td:nth-child(2) div.smalltext').text
      post_date = parse_post_date(post_date_str)

      body=nil
      downl_rank = @@options[:rank]||4
      if rank>=downl_rank
        body = td2.css('div.post').inner_html.strip
        body=remove_quote(body)
      end

      posts<<{
        siteid:SID,
        mid:mid,
        tid:tid,
        body: body,
        addeduid:addeduid,
        addedby:addedby,
        addedrank:rank,
        activity:activity,
        addeddate: post_date,
        pnum:page
      }
    end

    #p posts.map { |pp| [ pp[:addeddate].to_s ] }
    #p "parse signature: #{@@options[:parse_signature]}"

    users_arr = users.values
    users_ranks_stat = users_arr.map{|x| x[:rank]}
    more3stars = users_arr.count{|x| x[:rank]>3} rescue 0

    first_post_date = posts.first[:addeddate]

    if true #need save
      Repo.insert_users(users_arr, SID)
      Repo.save_bounty(bounties.values, SID)
      Repo.save_user_bounty(user_bounty.values, SID)
      Repo.insert_posts(posts, tid, SID)
      Repo.insert_or_update_tpage(SID,tid,page,posts.size,first_post_date)
      Repo.update_thread_bot_date(tid,SID)
    else
      title = DB[:threads].where(siteid:SID, tid:tid).map(:title)
      p "tid:#{tid} page:#{page} inserted:#{posts.size} title:#{title}"
    end
    #p "[ parse_thread_page_html] tid:#{tid} pg:#{page} first:#{first_date.strftime("%F %H:%M")}"

    #{first_post_date: first_post_date} 
    {stars: more3stars, first_post_date:first_post_date, stat:users_ranks_stat} 
  end

  ##11-legendary
  def self.detect_user_rank(td)
    stars = td.css('div.smalltext > img[alt="*"]')
    legend = stars.first['src'].end_with?("legendary.gif") rescue false
    staff = stars.first['src'].end_with?("staff.gif") rescue false
    rank = legend || staff ? 11 : stars.size
  end

  def self.parse_post_date(date_str)
   
    now = date_now

    date = DateTime.parse(date_str) rescue DateTime.new(1900,1,1) #.new_offset(3/24.0)
    date>now ? date-1 : date
  end

  def self.remove_quote(text)
    ptext = Nokogiri::HTML.fragment(text)

    ptext.css('div.quoteheader').each do |el|
      if el.css("a").size>0
        href=el.css("a")[0]['href'] 
        th_m = href.split("topic=").last.scan(/\d+/)
        nnode = "[q #{th_m[0]}.#{th_m[1]}]" 
        el.add_next_sibling nnode
      end
    end 

    ptext.css("div.quoteheader").remove
    ptext.css("div.quote").remove

    #node.remove
    ptext.to_html
  end

end
