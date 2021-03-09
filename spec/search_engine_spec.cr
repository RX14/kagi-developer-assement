require "./spec_helper"
require "yaml"

private alias Date = SearchEngine::DateExtraction::Date

describe SearchEngine do
  describe "VERSION" do
    it "matches shards.yml" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      version.should eq(SearchEngine::VERSION)
    end
  end

  describe "#crawl" do
    it "returns crawl results for each URL" do
      engine = SearchEngine.new

      urls = [spec_url("github.html"), spec_url("sample1.html")]
      chan = engine.crawl(urls)

      while result = chan.receive?
        case result.url
        when spec_url("github.html")
          result.date.should be_nil
        when spec_url("sample1.html")
          result.date.should eq(Date.new(2019, 6, 10))
        else
          raise "BUG"
        end

        result.crawl_time.should be < 100.milliseconds
      end
    end

    it "results error results on error" do
      engine = SearchEngine.new

      urls = [spec_url("nonexistant"), spec_url("sample1.html")]
      chan = engine.crawl(urls)

      while result = chan.receive?
        case result.url
        when spec_url("nonexistant")
          result.date.should be_nil
          result.error_message.should eq("URL #{spec_url("nonexistant")} returned status NOT_FOUND")
        when spec_url("sample1.html")
          result.date.should eq(Date.new(2019, 6, 10))
          result.error_message.should be_nil
        else
          raise "BUG"
        end

        result.crawl_time.should be < 100.milliseconds
      end
    end
  end
end
