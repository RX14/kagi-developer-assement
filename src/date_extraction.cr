require "./crawler"

# Implements date extraction from `Page` objects using the HTML content and the
# URL.
module SearchEngine::DateExtraction
  DATE_EXTRACTORS = [
    ->extract_date_from_url(Crawler::Page),
    ->extract_date_from_opengraph(Crawler::Page),
    ->extract_date_from_rdf(Crawler::Page),
    ->extract_date_from_time_element(Crawler::Page),
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

    def self.new(time : Time)
      new(time.year, time.month, time.day)
    end

    # Two dates are equal if their year, month, and day are identical
    def_equals_and_hash @year, @month, @day

    # :nodoc:
    MONTH_NAMES = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

    # Converts this `Date` to JSON.
    #
    # Representation is either `"2020"`, `"Jan, 2020"`, or `"Jan 1, 2020"`
    # depending on the accuracy of this date.
    def to_json(builder)
      case {year = @year, month = @month, day = @day}
      when {Int32, Int32, Int32}
        str = "#{MONTH_NAMES[month - 1]} #{day}, #{year}"
      when {Int32, Int32, nil}
        str = "#{MONTH_NAMES[month - 1]}, #{year}"
      when {Int32, nil, nil}
        str = "#{year}"
      else
        raise "BUG: unreachable"
      end

      str.to_json(builder)
    end
  end

  # Represents the result of a date extractor. Each date extractor will produce
  # a `Date`, with associated confidence value between 0 and 10.
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
  def self.extract_date_from_url(page : Crawler::Page) : Result?
    # Match URLs which contain 2021-01-01 or 2021/01/01 or 20210101.
    # Pages before 2000 are not matched for false positives.
    # TODO: try and detect american date formats?
    match = page.url.path.match(/\b(20\d\d)(?:[\/\-_](\d\d?)(?:[\/\-_](\d\d?))?)?\b/)
    match ||= page.url.path.match(/\b(20\d\d)(\d\d)(\d\d)\b/)
    return unless match

    year = match[1].to_i
    month = match[2]?.try(&.to_i)
    day = match[3]?.try(&.to_i)

    Result.new(Date.new(year, month, day), 7)
  end

  # Extracts publication date from opengraph tags in the page.
  #
  # See https://ogp.me/
  def self.extract_date_from_opengraph(page : Crawler::Page) : Result?
    node = page.html.xpath_node("//meta[@property='article:published_time']")
    return unless node

    return unless time = node["content"]?
    time = Time.parse_iso8601(time)

    Result.new(Date.new(time), 9)
  end

  # Extracts publication date from RDF tags in the page.
  #
  # See https://schema.org/datePublished
  def self.extract_date_from_rdf(page : Crawler::Page) : Result?
    node = page.html.xpath_node("//meta[@itemprop='datePublished']")
    return unless node

    return unless time = node["content"]?

    if date = fuzzy_parse_date(time)
      Result.new(date, 9)
    end
  end

  # Extracts publication date from <time> elements in the page.
  #
  # The first time element is used, but if there are more than one the score is
  # lowered because we can't be sure the date chosen is the correct one.
  #
  # TODO: handle multiple of the same date as a single date, and prefer repeated
  # dates.
  def self.extract_date_from_time_element(page : Crawler::Page) : Result?
    nodes = page.html.xpath_nodes("//time | //*[@datetime]")
    return if nodes.empty?

    node = nodes.first
    datetime = node["datetime"]? || node.text

    score = nodes.size > 1 ? 4 : 6
    if date = fuzzy_parse_date(datetime)
      return Result.new(date, score)
    end
  end

  MONTHS_REGEX = "(?<human_month>Jan(uary)?|Feb(uary)?|Mar(ch)?|Apr(il)?|May|June?|July?" +
                 "|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)"
  DATE_REGEXES = [
    /\b((?<day>\d\d?)(st|nd|rd|th)?\s+)(#{MONTHS_REGEX},?\s+)(?<year>20\d\d)\b/i,
    /\b(#{MONTHS_REGEX}\s+)((?<day>\d\d?)(st|nd|rd|th)?,?\s+)?(?<year>20\d\d)\b/i,
    /\b(?<year>20\d\d)([\/-](?<month>\d\d?)([\/-](?<day>\d\d?))?)?/i,
  ]

  # Attempt to turn a string into a `Date`. Supports several human readable or
  # machine readable formats.
  def self.fuzzy_parse_date(date : String) : Date?
    DATE_REGEXES.each do |regex|
      if match = regex.match(date)
        year = match["year"].to_i
        month = match["month"]?.try(&.to_i) || parse_month(match["human_month"]?)
        day = match["day"]?.try(&.to_i)
        return Date.new(year, month, day)
      end
    end
  end

  private def self.parse_month(month : String?) : Int32?
    return unless month

    case month.downcase
    when .starts_with? "jan" then 1
    when .starts_with? "feb" then 2
    when .starts_with? "mar" then 3
    when .starts_with? "apr" then 4
    when .starts_with? "may" then 5
    when .starts_with? "jun" then 6
    when .starts_with? "jul" then 7
    when .starts_with? "aug" then 8
    when .starts_with? "sep" then 9
    when .starts_with? "oct" then 10
    when .starts_with? "nov" then 11
    when .starts_with? "dec" then 12
    else
      raise "BUG: regex matched invalid date"
    end
  end
end
