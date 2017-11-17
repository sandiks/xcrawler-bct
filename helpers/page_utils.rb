

class PageUtil

  def self.get_psize(sid=0)
    posts_on_page_sites=[0,20,20,50,20,20,25,77,88,20,20]
    posts_on_page_sites[sid]
  end


  def self.calc_last_page(responses, page_size=50)
    return [1,1] if responses == 0

    post_count = (responses)%page_size
    post_count =page_size if post_count ==0

    page = (responses)/page_size+1
    page-=1 if post_count==page_size

    [page,post_count]
  end

end