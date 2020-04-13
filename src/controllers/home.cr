require "../framework"

class HomeController
  include Balloon::Controller

  skip_auth ["/"], GET, POST

  get "/" do |env|
    if (actors = Actor.all).empty?
      actor = Actor.new("", "")

      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/home/first_time.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/home/first_time.json.ecr"
      end
    else
      if accepts?("text/html")
        env.response.content_type = "text/html"
        render "src/views/home/index.html.ecr"
      else
        env.response.content_type = "application/json"
        render "src/views/home/index.json.ecr"
      end
    end
  end

  post "/" do |env|
    if (actors = Actor.all).empty?
      actor = Actor.new(*params(env))

      if actor.valid?
        actor.save
        session = Session.new(actor).save
        payload = {sub: actor.id, jti: session.session_key, iat: Time.utc}
        jwt = Balloon::JWT.encode(payload)

        if accepts?("text/html")
          env.response.cookies["AuthToken"] = jwt
          env.redirect "/actors/#{actor.username}"
        else
          env.response.content_type = "application/json"
          {jwt: jwt}.to_json
        end
      else
        if accepts?("text/html")
          env.response.content_type = "text/html"
          render "src/views/home/first_time.html.ecr"
        else
          env.response.content_type = "application/json"
          render "src/views/home/first_time.json.ecr"
        end
      end
    else
      not_found
    end
  rescue KeyError
    env.redirect "/"
  end

  private def self.params(env)
    params = accepts?("text/html") ? env.params.body : env.params.json
    {"username", "password"}.map { |p| params[p].as(String) }
  end
end
