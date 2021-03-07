require "./spec_helper"
require "yaml"

describe SearchEngine do
  describe "VERSION" do
    it "matches shards.yml" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      version.should eq(SearchEngine::VERSION)
    end
  end
end
