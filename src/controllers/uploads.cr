require "../framework"
require "uuid"

class UploadsController
  include Balloon::Controller

  post "/uploads" do |env|
    filename = nil
    filepath = nil
    HTTP::FormData.parse(env.request) do |part|
      if part.name == "file"
        filename = env.current_account?.not_nil!.actor.id.to_s
        filepath = File.join("uploads", *Tuple(String, String, String).from(UUID.random.to_s.split("-")[0..2]))
        if (extension = part.filename)
          extension = File.extname(extension)
          filename = "#{filename}#{extension}"
        end
        Dir.mkdir_p(File.join(Kemal.config.public_folder, filepath))
        File.open(File.join(Kemal.config.public_folder, filepath, filename), "w") do |file|
          IO.copy(part.body, file)
        end
      end
    end
    if filename && filepath
      env.response.headers["Location"] = "#{Balloon.host}/#{filepath}/#{filename}"
      created
    else
      bad_request
    end
  end

  delete "/uploads/:p1/:p2/:p3/:id" do |env|
    p1, p2, p3, id = env.params.url.select("p1", "p2", "p3", "id").values
    unless [p1, p2, p3].all? { |n| n =~ /^[a-z0-9-]+$/ }
      bad_request
    end
    unless id =~ /^([0-9-]+)(\.[^.]+)?$/
      bad_request
    end
    unless env.current_account?.not_nil!.actor.id.to_s == $1
      forbidden
    end
    filepath = File.join(Kemal.config.public_folder, "uploads", p1, p2, p3, id)
    if File.exists?(filepath)
      File.delete(filepath)
      ok
    else
      not_found
    end
  end
end
