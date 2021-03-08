require "./crawler"

# Implements date extraction from `Page` objects using the HTML content and the
# URL.
module SearchEngine::DateExtraction
  DATE_EXTRACTORS = [
    ->extract_date_from_url(Crawler::Page),
  ] of Crawler::Page -> DateExtraction::Result?

  # Extracts a date from a `Crawler::Page` by running all registered date
  # extractors (in `DATE_EXTRACTORS`), and picking the highest-confidence result
  # which is accurate to the day. If there is no result accurate to the day
  # available, it'll pick the highest confidence fuzzy result.
  def self.extract_date(page : Crawler::Page) : Date?
    results = DATE_EXTRACTORS.compact_map do |extractor|
      extractor.call(page)
    rescue ex
      nil
    end

    # TODO: score results higher if multiple extractors agree
    results.sort_by! { |r| -r.confidence }

    exact_result = results.find(&.exact?)
    return exact_result.date if exact_result

    # There are no exact results, choose the first non-exact result.
    if result = results.first?
      result.date
    end
  end

  # Represents a fuzzy date in time. This is accurate to the year, month, or day
  # depending on which fields are populated.
  class Date
    getter year : Int32
    getter month : Int32?
    getter day : Int32?

    def initialize(@year, @month = nil, @day = nil)
      raise ArgumentError.new("Date has day but no month!") if @day && !@month
    end

    # Two dates are equal if their year, month, and day are identical
    def_equals_and_hash @year, @month, @day
  end

  # Represents the result of a date extractor. Each date extractor will produce
  # a `Date`, with associated confidence value betwene 0 and 10.
  class Result
    # The date extracted from the page.
    getter date : Date

    # The confidence of `date` (0..10).
    getter confidence : Int32

    def initialize(@date, @confidence)
      unless 0 <= confidence <= 10
        raise ArgumentError.new("confidence must be 0..10 (was #{confidence})")
      end
    end

    # Returns true if the date of this result is accurate to a single day.
    def exact? : Bool
      !!date.day
    end
  end

  # Extracts a date from the URL of a page. Works for many blog pages which have
  # URLs like "/blog/2020/01/2/title".
  def self.extract_date_from_url(page : Crawler::Page)
    # Match URLs which contain 2021-01-01 or 2021/01/01 or 20210101.
    # Pages before 2000 are not matched for false positives.
    # TODO: try and detect american date formats?
    match = page.url.path.match(/\b(20\d\d)(?:[\/\-_](\d\d?)(?:[\/\-_](\d\d?))?)?\b/)
    match ||= page.url.path.match(/\b(20\d\d)(\d\d)(\d\d)\b/)
    return unless match

    year = match[1].to_i
    month = match[2]?.try(&.to_i)
    day = match[3]?.try(&.to_i)

    Result.new(Date.new(year, month, day), 2)
  end
end
