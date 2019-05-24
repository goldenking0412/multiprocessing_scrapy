require 'rest-client'
require 'csv'

require 'thread'
require 'thwait'
require 'byebug'

# Please change this script so that it outputs to a CSV with:
# COL 1 = url
# COL 2  = content_security_policy OR content_security_policy_report_only OR empty if neither
# COL 3 = "content_security_policy" or "content_security_policy_report_only" or "none" (depending on which was used)
# COL 4 = should not exist in theory, but if a site has both content_security_policy and content_security_policy_report_only then output content_security_policy first in COL 2, and then output content_security_policy_report_only in COL 4

# Please then make it so the requests are multithreaded because there's going to be thousands of URLs. So you'll likely want to load the URLs first, then fire off some threads reading URLs from a thread-safe queue, then finally at the end, output the results to the file

# The output file should live in /output/[yyyy-mm-dd].csv

# Make sure to use quotation marks so the csv works right even when the csp policies have commas

$url_length = 0
$web_list = Array.new
$counter = 0
$number_of_threads = 2
$thread_counter = 0
$thread_list = Array.new

$data = Array.new

class RowData
  def initialize(url, content_security_policy, content_security_policy_report_only)
    @url = url
    @content_security_policy = content_security_policy
    @content_security_policy_report_only = content_security_policy_report_only
  end

  def getURL
    return @url
  end

  def getCSP
    return @content_security_policy
  end

  def getCSPRO
    return @content_security_policy_report_only
  end
end

def readAllUrls
  File.readlines('websites.txt').each do |url|
    url = url.strip
    if (!(url.nil? || url.empty?)) && (url =~ /\A#{URI::regexp}\z/)
      $web_list.push url
      $url_length += 1
    end
  end
end

def scrapeThread
  while $counter < $url_length
    if $counter < $url_length
      url = $web_list[$counter]
      $counter+=1

      response = RestClient.get(url, headers={})
      if response.code != 200
        next
      end
      content_security_policy = response.headers[:content_security_policy]
      content_security_policy_report_only = response.headers[:content_security_policy_report_only]
      datum = RowData.new(url, content_security_policy, content_security_policy_report_only)
      $data[$counter] = datum
      puts url
    else
      return
    end
  end
end

def isEmpty data
  return data.nil? || data.empty?
end

def writeFile
  counter = 0  
  col1 = ""
  col2 = "" 
  col3 = "" 
  col4 = ""
  CSV.open("output.csv", "wb") do |csv|
    while counter < $data.length
      datum = $data[counter]
      if datum.nil?
        counter += 1
        next
      end
      col1 = datum.getURL
      if datum.getCSP && datum.getCSPRO
        col2 = "\"" + datum.getCSP + "\""
        col4 = "\"" + datum.getCSPRO + "\""
        col3 = "both"
      elsif datum.getCSP && isEmpty(datum.getCSPRO)
        col2 = "\"" + datum.getCSP + "\""
        col3 = "content_security_policy"
      elsif isEmpty(datum.getCSP) && datum.getCSPRO
        col2 = "\"" + datum.getCSPRO + "\""
        col3 = "content_security_policy_report_only"
      elsif isEmpty(datum.getCSP) && isEmpty(datum.getCSPRO)
        col2 = ""
        col3 = "neither"
      end
      csv << [col1, col2, col3, col4]
      col4 = ""
      counter += 1
    end
  end
end

readAllUrls()
while $thread_counter < $number_of_threads
  $thread_list[$thread_counter] = Thread.new{scrapeThread}
  # $thread_list[$thread_counter].join
  $thread_counter += 1
end

$thread_list.each do |thread|
  thread.join
end
writeFile()