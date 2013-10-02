# coding: utf-8
require 'spec_helper'

describe MogileImageStore::UrlHelper do
  describe "#attachment_url" do
    it "returns the url for given key" do
      attachment_url('1234567890abcdef1234567890abcdef.pdf').should == MogileImageStore.backend['base_url'] + 'raw/1234567890abcdef1234567890abcdef.pdf'
    end
  end
end
