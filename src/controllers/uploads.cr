require "../framework/controller"
require "../services/upload_service"

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

  post "/uploads" do |env|
    result = nil
    env.params.files.each do |_, part|
      if (filename = part.filename.presence) && part.tempfile.size > 0
        result = UploadService.upload(part.tempfile, filename, env.account.actor.id!)
        break
      end
    end

    if result && result.valid?
      created result.file_uri.not_nil!, result.file_path.not_nil!
    else
      bad_request
    end
  end

  # trix-style deleting

  delete "/uploads/:p1/:p2/:p3/:id" do |env|
    p1, p2, p3, id = env.params.url.select("p1", "p2", "p3", "id").values
    path = "/uploads/#{p1}/#{p2}/#{p3}/#{id}"

    result = UploadService.delete(path, env.account.actor.id!)

    if result.success? && !result.deleted_paths.empty?
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

    result = UploadService.delete(path, env.account.actor.id!)

    if result.success? && !result.deleted_paths.empty?
      ok
    else
      not_found
    end
  end
end
