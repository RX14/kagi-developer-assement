require "./spec_helper"

describe SearchEngine::Crawler do
  it "parses pages" do
    page = SearchEngine::Crawler.crawl(spec_url("sample1.html"))
    title = page.html.xpath_node("//head/title").not_nil!.content
    title.should eq("Text Summarization | Text Summarization Using Deep Learning")
  end

  it "raises on non-200 error code" do
    expect_raises(SearchEngine::Crawler::Error, "returned status INTERNAL_SERVER_ERROR") do
      SearchEngine::Crawler.crawl(spec_url("status/500"))
    end
  end

  it "handles redirects" do
    page = SearchEngine::Crawler.crawl(spec_url("redirect"))
    title = page.html.xpath_node("//head/title").not_nil!.content
    title.should eq("Text Summarization | Text Summarization Using Deep Learning")
  end
end
