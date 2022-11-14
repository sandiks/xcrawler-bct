require 'sequel'
require 'logger'
require_relative  'page_utils'

Sequel.datetime_class = DateTime

class Repo

  DB = Sequel.connect('postgres://btuser:test123@localhost:5432/bittalk')
  #DB = Sequel.connect(:adapter => 'mysql2',:host => 'localhost',:database => 'bittalk',:user => 'root')
  #DB.loggers << Logger.new($stdout)

  def self.get_db
    DB
  end

  def self.datetime_now(sid=0)
    case sid
     when 0; DateTime.now.new_offset(3/24.0)
     when 9; DateTime.now.new_offset(0/24.0)
    end
  end

  def self.get_forum_name(fid,sid=0)
    ff = DB[:forums].where(fid: fid).first
    lev1 = ff[:name]
  end


  def self.get_forum_name_by_tid(tid,sid=0)
    return if sid==0

    thr = DB[:threads].where(tid: tid).first
    if not thr.nil?
      ff = DB[:forums].where(fid: thr[:fid]).first
      ff[:name]
    end
  end

  def self.update_forum_bot_date(fid,sid=0)
    rec = DB[:forums].filter(fid: fid)
    rec.update(:bot_updated => datetime_now)
  end

  def self.get_forum_bot_date(fid,sid=0)
    rec = DB[:forums].filter(fid: fid)
    rec.first[:bot_updated] #.new_offset(3/24.0)
  end


  def self.insert_forums(forums)

    count=0
    DB.transaction do

      exist = DB[:forums].map(:fid)

      forums.each do |ff|
        begin
          if not exist.include? ff[:fid]
            DB[:forums].insert(ff)
            count+=1
          end
        rescue =>ex
          puts "[error fid:#{ff[:fid]}] #{ex.message}"
        end

      end

    end

    count
  end

  #####thread
  def self.get_thread_bot_date(tid,sid=0)
    rec = DB[:threads].filter(tid: tid)
    rec.first[:bot_updated].new_offset(3/24.0)
  end

  def self.get_thread(tid,sid=0)
    return if sid==0
    thr = DB[:threads].first(tid: tid)
  end

  def self.insert_or_update_forum(forum,sid=0)
    rec = DB[:forums].where(fid: forum[:fid])

    if 1 != rec.update(:name => forum[:name])
      DB[:forums].insert(forum)
    end
  end

  def self.update_thread_bot_date(tid,sid=0)
    rec = DB[:threads].filter(tid: tid)
    rec.update(bot_updated: datetime_now)
  end

  def self.get_thread_bot_date(tid,sid=0)
    rec = DB[:threads].filter(tid: tid)
    rec.first[:bot_updated]
  end


  def self.insert_threads(threads,sid=0)

    count=0
    DB.transaction do

      exist = DB[:threads].map(:tid)

      threads.each do |thr|

        begin
          if not exist.include? thr[:tid]
            DB[:threads].insert(thr)
            count+=1
          else
            #puts "update thread tid:#{thr[:tid]} title:#{thr[:title]}"
            DB[:threads].filter(tid: thr[:tid]).update(thr)
          end
        rescue =>ex
          puts "[error tid:#{thr[:tid]}] #{ex.class}"
        end

      end

    end #end trans
    count
  end

  def self.insert_or_update_threads_for_forum(threads,sid=0, full_update=true)

    count=0
    DB.transaction do

      exist = DB[:threads].map(:tid)
          #rec.update(fid:tt[:fid], title:tt[:title], responses: tt[:responses], viewers: tt[:viewers], updated: tt[:updated])
          #rec.update(responses: tt[:responses], viewers: tt[:viewers], updated: tt[:updated])

      threads.each do |thr|
        begin

          if not exist.include? thr[:tid]
            DB[:threads].insert(thr)
            count+=1
          else
            #puts "update thread tid:#{thr[:tid]} title:#{thr[:title]}"
            if full_update
              DB[:threads].filter(tid: thr[:tid]).update(thr)
            else
              DB[:threads].filter(tid: thr[:tid])
              .update(title: thr[:title], responses: thr[:responses], viewers: thr[:viewers], updated: thr[:updated])
            end
          end

        rescue =>ex
          puts "[error:insert_or_update_threads_for_forum tid:#{thr[:tid]}] #{ex.message}"
        end
      end
    end
    count
  end
  def self.insert_into_threads_responses(fid, forum_page_threads)

    inserted=0
    DB.transaction do

      forum_page_threads.each do |tt|

        if true #exist[tt[:tid]] != tt[:responses]
          tid=tt[:tid]
          dd=DateTime.now.new_offset(0/24.0)
          day= dd.day
          hour= dd.hour

          rr = {fid:tt[:fid], tid: tid, responses:tt[:responses],
            last_post_date:tt[:updated], parsed_at:dd, day:day, hour:hour}

          rr = DB[:threads_responses].where({ tid: tid, last_post_date:tt[:updated] })
          # update record
          upd = rr.update({responses: tt[:responses], parsed_at: dd, day: day, hour: hour})
          if 1 != upd
            DB[:threads_responses].insert(rr)
          end

          inserted+=1

        else
          #p "#{tt[:tid]} exist with same responses #{tt[:responses]}"
        end
      end
    end
    inserted
  end

  def self.insert_into_threads_responses_with_check_on_date(sid, fid, forum_page_threads)

    inserted=0
    DB.transaction do

      exist = DB[:threads_responses].filter(fid: fid).to_hash(:tid, :responses)

      forum_page_threads.each do |tt|
        tid=tt[:tid]
        title=tt[:title]

        if exist[tt[:tid]] != tt[:responses]
          dd=DateTime.now.new_offset(0/24.0)
          day= dd.day
          hour= dd.hour

          rr = {fid:tt[:fid], tid:tid, responses:tt[:responses],
            last_post_date:tt[:updated], parsed_at:dd, day:day, hour:hour}

          DB[:threads_responses].filter(fid:fid, tid:tid, day:day, hour:hour).delete
          DB[:threads_responses].insert(rr)

          inserted+=1

        else
          #p "#{tt[:tid]} exist with same responses #{tt[:responses]}"
        end
      end
    end
    inserted
  end

  def self.insert_into_user_merits(user_merits)

    inserted=0
    DB.transaction do
      dbusers = DB[:user_merits].to_hash(:uid,:merit)

      user_merits.each do |uid, merit|

        dd=DateTime.now.new_offset(0/24.0)
        if !dbusers[uid] || dbusers[uid]!=merit
          DB[:user_merits].insert({uid:uid, merit:merit, date:dd })
          #p "inserted #{uid}"
          inserted+=1
        end
      end
    end

    inserted
  end

  def self.insert_posts(posts,threads_id,sid=0)
    count=0
    DB.transaction do

      exist = DB[:posts].filter(tid: threads_id).map(:mid)
      posts.each do |pp|
        begin

          if not exist.include? pp[:mid]
            DB[:posts].insert(pp)
            count+=1
          else
            #DB[:posts].filter(mid: pp[:mid]).update(addeddate: pp[:addeddate])
            #DB[:posts].filter(mid: pp[:mid]).update(body:pp[:body])
          end
        rescue =>ex
          puts "[error mid:#{pp[:mid]}] #{ex.message} tid:#{threads_id}"
        end

      end

    end

    count
  end

  def self.insert_users(users,sid=0)

    count=0
    DB.transaction do

      dbusers = DB[:users].to_hash(:uid,:rank)

      users.each do |us|
        uid = us[:uid]
        next if !uid

        begin
          if !dbusers.has_key?(uid)
            DB[:users].insert( us.merge({created_at:DateTime.now.new_offset(3/24.0)}) )
            count+=1
          else
            if dbusers[uid]!=us[:rank]
              #p "[update user rank #{uid}]  old:#{dbusers[uid]} new:#{us[:rank]}"
              DB[:users].filter(uid: uid).update(rank: us[:rank])
            end
          end
        rescue =>ex
          puts "[error_insert_users] #{ex.message} #{us}"
        end

      end

    end

    count
  end

  def self.save_bounty(bounties ,sid=9)

    count=0
    DB.transaction do
      exist = DB[:bct_bounty].map(:name)
      bounties.each do |bb|
        begin
          unless exist.include? bb[:name]
            DB[:bct_bounty].insert(bb.merge({created_at:DateTime.now.new_offset(3/24.0)}))
            count+=1
          else
            rec = DB[:bct_bounty].filter(name:bb[:name]).first
            rec.update(descr: bb[:descr]) if bb[:descr].size>rec[:descr].size
          end
        rescue =>ex
          puts "[error-save-bounty name:#{bb[:name]}] #{ex.class}"
        end
      end
    end #end trans
    count
  end

  def self.save_user_bounty(user_bounties ,sid=9)

    count=0
    DB.transaction do

      db_user_bounties = DB[:bct_user_bounty].to_hash(:uid,:bo_name)

      user_bounties.each do |bb|
        uid= bb[:uid]
        bounty_name = bb[:bo_name]

        begin
          if db_user_bounties[uid] != bounty_name
            DB[:bct_user_bounty].insert(bb.merge({created_at:DateTime.now.new_offset(3/24.0)}))
            count+=1
          end
        rescue =>ex
          puts "[error-save-user-bounty bo_name:#{bb[:bo_name]}] #{ex.class}"
        end
      end
    end #end trans
    count
  end

  def self.get_tpages(tid,sid=0)
    DB[:tpages].filter(tid:tid).to_hash(:page,:postcount)
  end

  def self.calc_page(tid,curr_responses,sid=0)

    page_size = PageUtil.get_psize(sid)

    last_page_with_post_count = PageUtil.calc_last_page(curr_responses, page_size)

    last_page = last_page_with_post_count[0]
    last_posts_count = last_page_with_post_count[1]

    db_last_posts_count = DB[:tpages].filter(tid:tid, page:last_page).map(:postcount).first||0

    all_pages=(1..last_page-1).to_a

    new_posts = true
    new_posts = db_last_posts_count<last_posts_count ||(db_last_posts_count>last_posts_count)

    page =0
    if not new_posts

      pages_count = DB[:tpages].filter(tid:tid).map([:page,:postcount])

      pages_less50 = pages_count.select{|p| p[1]!=page_size && p[0]<last_page}.map { |p| p[0] }
      pages50 = pages_count.select{|p| p[1]== page_size && p[0]<last_page}.map { |p| p[0] }

      if pages_count.empty?
        page= last_page

      elsif not pages_less50.empty?
        page = pages_less50.max
      elsif
        page= (all_pages-pages50).max||0
      end

    else
      page = last_page
    end

    page

  end

  def self.insert_or_update_tpage(sid=0,tid,page,count,first_post_date)
    return if page==0 || sid==0

    #update table[tpages] with post count on page
    rec = DB[:tpages].where({tid:tid, page:page })

    #p "update tpage #{rec.sql}"
    upd =rec.update({postcount:count,fp_date: first_post_date})

    if 1 != upd
      DB[:tpages].insert({tid:tid, page:page, postcount:count, fp_date: first_post_date})
    end
  end

  def self.insert_or_update_tpage_ranks(tid, page, count, first_post_date, grouped_ranks)
    return if page<1

    rec = DB[:tpage_ranks].where({ tid:tid, page:page })
    #p "update tpage #{rec.sql}"
    upd =rec.update({postcount:count,fp_date: first_post_date}.merge(grouped_ranks))
    if 1 != upd
      DB[:tpage_ranks].insert({tid:tid, page:page, postcount:count, fp_date: first_post_date}.merge(grouped_ranks))
    end
  end

end
