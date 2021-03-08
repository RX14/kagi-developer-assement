require "./spec_helper"

private alias DateExtraction = SearchEngine::DateExtraction
private alias Result = DateExtraction::Result

describe SearchEngine::DateExtraction do
  describe "Result" do
    it "accepts confidence in range 0..10" do
      now = Time.utc
      Result.new(now..now, 0)
      Result.new(now..now, 10)
      expect_raises(ArgumentError, "confidence must be 0..10 (was -1)") do
        Result.new(now..now, -1)
      end
      expect_raises(ArgumentError, "confidence must be 0..10 (was 11)") do
        Result.new(now..now, 11)
      end
    end

    describe "exact?" do
      it "returns true if start and end are on the same day" do
        result = Result.new(Time.utc(2020, 1, 1, 0, 0, 0)..Time.utc(2020, 1, 1, 0, 0, 0), 0)
        result.exact?.should be_true

        result = Result.new(Time.utc(2020, 1, 1, 0, 0, 0)..Time.utc(2020, 1, 1, 23, 59, 59), 0)
        result.exact?.should be_true

        result = Result.new(Time.utc(2020, 1, 1, 23, 59, 59)..Time.utc(2020, 1, 1, 0, 0, 0), 0)
        result.exact?.should be_true
      end

      it "returns false if start and end are on different days" do
        result = Result.new(Time.utc(2020, 1, 1, 0, 0, 0)..Time.utc(2019, 12, 31, 23, 59, 59), 0)
        result.exact?.should be_false

        result = Result.new(Time.utc(2020, 1, 1, 0, 0, 0)..Time.utc(2020, 1, 2, 0, 0, 0), 0)
        result.exact?.should be_false
      end
    end
  end

  describe ".extract_date_from_url" do
    it "extracts dates from URLs" do
      uri = URI.parse("http://example.com/blog/2020/03/12/article")
      page = SearchEngine::Crawler::Page.new(uri, empty_html)
      result = DateExtraction.extract_date_from_url(page).not_nil!

      result.confidence.should eq(2)
      result.range.should eq(Time.utc(2020, 3, 12)..Time.utc(2020, 3, 12).at_end_of_day)
      result.exact?.should be_true
    end
  end
end
