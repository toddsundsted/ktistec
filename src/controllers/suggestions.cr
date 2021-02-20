require "../framework/controller"
require "../models/tag/hashtag"
require "../models/tag/mention"

class SuggestionsController
  include Ktistec::Controller

  get "/tags" do |env|
    if (hashtag = env.params.query["hashtag"]?)
      Tag::Hashtag.match(hashtag).first?.try(&.first)
    elsif (mention = env.params.query["mention"]?)
      Tag::Mention.match(mention).first?.try(&.first)
    else
      bad_request("Missing Query Parameter")
    end
  end
end
