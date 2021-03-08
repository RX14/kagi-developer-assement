require "./spec_helper"

private alias DateExtraction = SearchEngine::DateExtraction
private alias Date = DateExtraction::Date
private alias Result = DateExtraction::Result

describe SearchEngine::DateExtraction do
  describe "Result" do
    it "accepts confidence in range 0..10" do
      date = Date.new(2021, 1, 1)
      Result.new(date, 0)
      Result.new(date, 10)
      expect_raises(ArgumentError, "confidence must be 0..10 (was -1)") do
        Result.new(date, -1)
      end
      expect_raises(ArgumentError, "confidence must be 0..10 (was 11)") do
        Result.new(date, 11)
      end
    end

    describe "exact?" do
      it "returns true if date is accurate to the day" do
        result = Result.new(Date.new(2020, 1, 1), 0)
        result.exact?.should be_true
      end

      it "returns false if date is not accurate to one day" do
        result = Result.new(Date.new(2020, 1), 0)
        result.exact?.should be_false
      end
    end
  end

  describe ".extract_date" do
    it "extracts a date from an exact URL" do
      page = page("http://example.com/blog/2020/03/12/article", empty_html)
      result = DateExtraction.extract_date(page)
      result.should eq(Date.new(2020, 3, 12))
    end

    it "extracts a date from a non-exact URL" do
      page = page("http://example.com/blog/2020/article", empty_html)
      result = DateExtraction.extract_date(page)
      result.should eq(Date.new(2020))
    end

    it "returns nil if no date can be extracted" do
      page = page("http://example.com/blog/article", empty_html)
      result = DateExtraction.extract_date(page)
      result.should be_nil
    end
  end

  describe ".extract_date_from_url" do
    it "extracts dates from URLs" do
      page = page("http://example.com/blog/2020/03/12/article", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2020, 3, 12))

      page = page("http://example.com/blog/2020/3/article", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2020, 3))

      page = page("http://example.com/blog/2020/article", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2020))

      page = page("http://example.com/blog/article-2020-2-3", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2020, 2, 3))

      page = page("http://example.com/blog/2020/2_3-article", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2020, 2, 3))

      page = page("http://example.com/20210308-article", empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.date.should eq(Date.new(2021, 3, 8))
    end

    it "doesn't extract dates from dubious URLs" do
      page = page("http://example.com/432021-2-8", empty_html)
      result = DateExtraction.extract_date_from_url(page)
      result.should be_nil

      page = page("http://example.com/21-2-8-article", empty_html)
      result = DateExtraction.extract_date_from_url(page)
      result.should be_nil

      # 20210308 as part of another number, not on it's own
      page = page("http://example.com/202103081-article", empty_html)
      result = DateExtraction.extract_date_from_url(page)
      result.should be_nil

      page = page("http://example.com/120210308-article", empty_html)
      result = DateExtraction.extract_date_from_url(page)
      result.should be_nil
    end
  end

  describe ".extract_date_from_opengraph" do
    it "ignores pages with no date" do
      page = page("http://example.com/article", empty_html)
      result = DateExtraction.extract_date_from_opengraph(page)
      result.should be_nil

      page = crawl("github.html")
      result = DateExtraction.extract_date_from_opengraph(page)
      result.should be_nil
    end

    it "extracts date from opengraph article:published_time properties" do
      page = page("http://example.com/article", <<-HTML)
        <html>
          <head>
            <meta property="article:published_time" content="2021-03-08T15:49:01Z" />
          </head>
        </html>
        HTML
      result = DateExtraction.extract_date_from_opengraph(page).not_nil!

      result.confidence.should eq(9)
      result.date.should eq(Date.new(2021, 3, 8))

      page = crawl("sample1.html")
      result = DateExtraction.extract_date_from_opengraph(page).not_nil!

      result.confidence.should eq(9)
      result.date.should eq(Date.new(2019, 6, 10))
    end
  end
end
