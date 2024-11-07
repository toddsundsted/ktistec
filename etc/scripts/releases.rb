#!/usr/bin/env ruby

# This is a simple Ruby script that demonstrates how to automate
# posting content.  The following environment variables are set when
# the server runs this script:
#
#   API_KEY      - authenticates the script with the server
#   KTISTEC_HOST - the base URL of the server instance
#   KTISTEC_NAME - the name of the server instance
#   USERNAME     - the username of the account the script is run as
#
# To enable this script, make it executable.
#
# Requires Ruby >= 3.0.0.
#
require 'dbm'
require 'json'
require 'kramdown'
require 'net/http'
require 'uri'

# GitHub repository to monitor:
REPO = "toddsundsted/ktistec"
# Title to set on post:
TITLE = "New Release of Ktistec"

uri = URI("https://api.github.com/repos/#{REPO}/releases")
response = Net::HTTP.get(uri, {"Accept" => "application/vnd.github+json", "X-GitHub-Api-Version" => "2022-11-28"})
json = JSON.parse(response)

recent = json.find { |item| !item['draft'] && !item["prerelease"] }

if recent
  DBM.open('releases', 0644, DBM::WRCREAT) do |dbm|
    name = recent['name']
    body = recent['body']
    unless dbm[name]
      dbm[name] = body
      uri = URI("#{ENV['KTISTEC_HOST']}/actors/#{ENV['USERNAME']}/outbox")
      body = {"type" => "Publish", "name" => TITLE, "content" => Kramdown::Document.new(body).to_html, "public" => true}.to_json
      Net::HTTP.post(uri, body, {"Content-Type" => "application/json", "Authorization" => "Bearer #{ENV['API_KEY']}"})
      puts "Posting release notes for #{name}"
    end
  end
end
