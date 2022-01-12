require "school"

class ContentRules
  def initialize(@actor : ActivityPub::Actor, @activity : ActivityPub::Activity)
  end

  def run
  end
end
