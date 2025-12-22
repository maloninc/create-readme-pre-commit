# spec/spec_helper.rb
require 'rack/test'
require 'rspec'

require File.expand_path '../../app.rb', __FILE__

ENV['RACK_ENV'] = 'test'

module RSpecMixin
  include Rack::Test::Methods
  def app() Sinatra::Application end
end

# For RSpec 2.x
RSpec.configure do |config|
  config.include RSpecMixin 

  config.formatter = :documentation
  config.tty = true
  config.color = true
end
