# `SearchEngine` implements the logic to crawl and extract dates from a list of
# URLs in parallel.
class SearchEngine
  VERSION = "0.1.0"

  # Crawls a list of URLs in parallel, returning a channel of `Result`s.
  # The channel will be closed once the final result is sent.
  def crawl(urls : Array(URI)) : Channel(Result)
    channel = Channel(Result).new(10)
    atomic = Atomic.new(urls.size)

    urls.each do |url|
      spawn do
        date = nil
        crawl_time = Time.measure do
          page = Crawler.crawl(url)
          date = DateExtraction.extract_date(page)
        end

        channel.send Result.new(url, date, crawl_time)

        if atomic.sub(1) == 1
          # We are the final fiber to complete, close the channel
          # We test against 1 because #sub returns the old value of the atomic.
          channel.close
        end
      end
    end

    channel
  end

  # A result for the search engine for a single URL.
  # Contains date extracted, as well as crawl time.
  class Result
    getter url : URI
    getter date : DateExtraction::Date?
    getter crawl_time : Time::Span

    def initialize(@url, @date, @crawl_time)
    end
  end
end

require "./crawler"
require "./date_extraction"
