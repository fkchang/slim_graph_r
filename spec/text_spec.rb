# frozen_string_literal: true

require "spec_helper"

RSpec.describe SlimGraphR::Text do
  describe ".wrap" do
    it "preserves ASCII labels" do
      expect(described_class.wrap("Architecture API", 10_000)).to eq(["Architecture API"])
    end

    it "preserves representative Unicode labels and combining marks" do
      label = "café 東京 e\u0301"

      expect(described_class.wrap(label, 10_000)).to eq([label])
    end
  end
end
