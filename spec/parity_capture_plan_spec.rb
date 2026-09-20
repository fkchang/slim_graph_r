# frozen_string_literal: true

require 'json'
require 'open3'
require 'spec_helper'
require_relative '../examples/parity/deployment_checkout_service'

RSpec.describe 'parity review capture planning' do
  def display_width(diagram)
    diagram.to_svg(id: 'capture-plan')[/<svg[^>]*\bwidth="(\d+)"/, 1].to_i
  end

  def plan_for(regions)
    script = <<~JS
      const { reviewCapturePlan } = require(process.argv[1]);
      process.stdout.write(JSON.stringify(reviewCapturePlan(JSON.parse(process.argv[2]))));
    JS
    helper = File.expand_path('../script/parity_capture_plan.js', __dir__)
    output, status = Open3.capture2('node', '-e', script, helper, JSON.generate(regions))
    expect(status).to be_success
    JSON.parse(output)
  end

  it 'expands a wide deployment review image while retaining a normal fitting page capture' do
    wide_width = display_width(ParityFixtures::DeploymentCheckoutService.diagram)
    fitting_width = display_width(SlimGraphR.diagram(:architecture) { node :reader; node :origin; flow :reader, :origin })
    expect(wide_width).to be > 1440
    expect(fitting_width).to be <= 1440

    wide = plan_for([{ index: 0, client_width: 1440, scroll_width: wide_width }])
    fitting = plan_for([{ index: 0, client_width: 1440, scroll_width: fitting_width }])

    expect(wide).to eq('mode' => 'expanded-scroll-regions', 'wide_region_indices' => [0])
    expect(fitting).to eq('mode' => 'full-page', 'wide_region_indices' => [])
  end
end
