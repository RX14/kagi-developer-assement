require "./crawler"

# Implements date extraction from `Page` objects.
module SearchEngine::DateExtraction
  DATE_EXTRACTORS = [
    ->extract_date_from_url(Page),
  ] of Page -> DateExtraction::Result?

  def self.extract_date(page : Page) : Time
    results = DATE_EXTRACTORS.compact_map do |extractor|
      extractor.call(page)
    rescue ex
      nil
    end

    # TODO: score results higher if multiple extractors agree
    results.sort_by! { |r| -r.confidence }

    exact_result = results.find(&.exact?)
    return exact_result.range.begin if exact_result

    # There are no exact results, choose the first
    results.first.range.begin
  end

  class Result
    # The range of times which
    getter range : Range(Time, Time)

    # Confidence (0..10)
    getter confidence : Int32

    def initialize(@range, @confidence)
      unless 0 <= confidence <= 10
        raise ArgumentError.new("confidence must be 0..10 (was #{confidence})")
      end
    end

    # Returns true if the start and end of range of this result are on the same
    # day.
    def exact?
      range.begin.at_beginning_of_day == range.end.at_beginning_of_day
    end
  end

  def self.extract_date_from_url(page : Crawler::Page)
    # Match URLs which contain 2021-01-01 or 2021/01/01 or 20210101.
    # Pages before 2000 are not matched for false positives.
    # TODO: try and detect american date formats?
    return unless match = page.url.path.match(/\b(20\d\d)[\/-_]?(\d\d?)?[\/-_]?(\d\d?)?\b/)
    year = match[1].to_i
    month = match[2]?.try(&.to_i)
    day = match[3]?.try(&.to_i)

    case {year, month, day}
    when {Int32, nil, nil}
      time = Time.utc(year, 1, 1)
      range = time..time.at_end_of_year
    when {Int32, Int32, nil}
      time = Time.utc(year, month, 1)
      range = time..time.at_end_of_month
    when {Int32, Int32, Int32}
      time = Time.utc(year, month, day)
      range = time..time.at_end_of_day
    else
      raise "BUG: unreachable"
    end

    Result.new(range, 2)
  end
end
