require "file_utils"
require "uuid"

require "../framework/controller"

class UploadsController
  include Ktistec::Controller

  post "/uploads" do |env|
    filename = nil
    filepath = nil
    env.params.files.each do |name, part|
      if part.filename.presence
        filename = env.account.actor.id.to_s
        filepath = File.join("uploads", *Tuple(String, String, String).from(UUID.random.to_s.split("-")[0..2]))
        if (extension = part.filename)
          extension = File.extname(extension)
          filename = "#{filename}#{extension}"
        end
        Dir.mkdir_p(File.join(Kemal.config.public_folder, filepath))
        part.tempfile.chmod(0o644) # fix permissions
        FileUtils.mv(part.tempfile.path, File.join(Kemal.config.public_folder, filepath, filename))
      end
    end
    if filename && filepath
      created "#{host}/#{filepath}/#{filename}", "/#{filepath}/#{filename}"
    else
      bad_request
    end
  end

  # trix-style deleting

  delete "/uploads/:p1/:p2/:p3/:id" do |env|
    p1, p2, p3, id = env.params.url.select("p1", "p2", "p3", "id").values
    unless [p1, p2, p3].all? { |n| n =~ /^[a-z0-9-]+$/ }
      bad_request
    end
    unless id =~ /^([0-9-]+)(\.[^.]+)?$/
      bad_request
    end
    unless env.account.actor.id.to_s == $1
      forbidden
    end
    filepath = File.join(Kemal.config.public_folder, "uploads", p1, p2, p3, id)
    if File.delete?(filepath)
      ok
    else
      not_found
    end
  end

  # filepond-style deleting

  private PATH_RE = /^\/uploads\/([a-z0-9-]+)\/([a-z0-9-]+)\/([a-z0-9-]+)\/(([0-9-]+)(\.[^.]+)?)$/

  delete "/uploads" do |env|
    unless (p = env.request.body.try(&.gets)) && (m = p.match(PATH_RE))
      bad_request
    end
    unless env.account.actor.id.to_s == m[5]
      forbidden
    end
    filepath = File.join(Kemal.config.public_folder, "uploads", m[1], m[2], m[3], m[4])
    if File.exists?(filepath)
      File.delete(filepath)
      ok
    else
      not_found
    end
  end
end
