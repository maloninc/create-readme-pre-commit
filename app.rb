require 'rubygems'
require 'bundler/setup'

# myapp.rb
require 'sinatra'
require 'json'

get '/hello' do
  output = "Hello world! Version 3. Now with test-suite! </br>"
  env_string = JSON.pretty_generate(ENV.to_a).gsub!("\n",'</br>')
  output += "Environment: </br> #{env_string} </br>"
  output
end

get '/greetings' do
  status 201
  return 'Hello!'
end

get '/hello-world' do
  status 201
  return 'Hello, World'
end


get "/google" do
  require "httparty"
  HTTParty.get('http://google.com', follow_redirects: true).body
end
