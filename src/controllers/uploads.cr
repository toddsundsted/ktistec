require "file_utils"
require "uuid"

require "../framework/controller"

class UploadsController
  include Ktistec::Controller

  # Represents an uploaded file with metadata.
  #
  private record Upload, actor_id : Int64, filepath : String do
    def exists?
      File.exists?(filepath)
    end

    def delete
      File.delete(filepath)
    end
  end

  # Authorizes upload access (path string variant).
  #
  # Validates the upload path string format, extracts ownership
  # information, and returns the upload if the authenticated user owns
  # it, `nil` otherwise.
  #
  private def self.get_upload(env, path : String)
    # validate path format and extract components
    unless (match = path.match(/^\/uploads\/([a-z0-9-]+)\/([a-z0-9-]+)\/([a-z0-9-]+)\/(([0-9]+)(\.[^.]+)?)$/))
      return nil
    end

    p1, p2, p3, filename, id_str = match[1], match[2], match[3], match[4], match[5]

    actor_id = id_str.to_i64? || return nil

    if (account = env.account?) && account.actor.id == actor_id
      filepath = File.join(Kemal.config.public_folder, "uploads", p1, p2, p3, filename)
      Upload.new(actor_id: actor_id, filepath: filepath)
    end
  end

  # Authorizes upload access (path components variant).
  #
  # Validates the upload path components, extracts ownership
  # information, and returns the upload if the authenticated user owns
  # it, `nil` otherwise.
  #
  private def self.get_upload(env, p1 : String, p2 : String, p3 : String, id : String)
    # validate path components
    unless [p1, p2, p3].all? { |n| n =~ /^[a-z0-9-]+$/ }
      return nil
    end
    unless id =~ /^(([0-9]+)(\.[^.]+)?)$/
      return nil
    end

    filename = $1 # full filename (e.g., "123.txt")
    id_str = $2 # actor ID (e.g., "123")

    actor_id = id_str.to_i64? || return nil

    if (account = env.account?) && account.actor.id == actor_id
      filepath = File.join(Kemal.config.public_folder, "uploads", p1, p2, p3, filename)
      Upload.new(actor_id: actor_id, filepath: filepath)
    end
  end

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

    unless (upload = get_upload(env, p1, p2, p3, id))
      not_found
    end

    if upload.exists?
      upload.delete
      ok
    else
      not_found
    end
  end

  # filepond-style deleting

  delete "/uploads" do |env|
    unless (path = env.request.body.try(&.gets))
      bad_request
    end

    unless (upload = get_upload(env, path))
      not_found
    end

    if upload.exists?
      upload.delete
      ok
    else
      not_found
    end
  end
end
