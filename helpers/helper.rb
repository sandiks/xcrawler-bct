require 'sequel'
require_relative  'socksify_mechanize'

class Time
  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, 0/24.0)
  end
end

def download_page(url, encoding="", use_tor = false)#win1251, utf-8, ISO-8859-1 
  headers = { 'User-Agent' => 'Windows / Firefox 32: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/32.0'}

  if use_tor
    #p "dowload through tor"
    browser = Mechanize.new
    browser.agent.set_socks('localhost', 9050)
    resp =browser.get(url,headers).body
  else

    uri = URI.parse(url)
    #req = Net::HTTP::Get.new(uri.path,headers)
    #response = Net::HTTP.start(uri.host,uri.port) { |http| http.request(req) }
    #open(url,headers)
    
    if encoding == "win1251"
      downl_win1251(url, headers)
    elsif encoding == "ISO-8859-1"
      open(url,headers).read
    else
      open(url,headers).read
    end

  end
end

def downl_win1251(url, headers)
  html = open(url,headers).read
  html.force_encoding("windows-1251")
  html.encode!("windows-1251", :undef => :replace, :replace => "", :invalid => :replace)

end

def site_url(url)
  if not url.start_with? 'http'
    "#{url}"
  else
    url
  end
end

def fetch(uri_str, limit = 10)
  # You should choose better exception.
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0

  url = URI.parse(URI.encode(uri_str.strip))

  #get path
  headers = {}
  req = Net::HTTP::Get.new(url.path,headers)
  #start TCP/IP
  response = Net::HTTP.start(url.host,url.port) { |http|
    http.request(req)
  }

  case response
  when Net::HTTPSuccess
  then #print final redirect to a file
    return response
    # if you get a 302 response
  when Net::HTTPRedirection
  then
    puts "this is redirect " + response['location']
    url = "#{response['location']}"
    return fetch(url, limit-1)
  else
    response.error!
  end
end
