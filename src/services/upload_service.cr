require "file_utils"
require "uuid"
require "kemal"

module UploadService
  Log = ::Log.for(self)

  # Result of uploading a file.
  #
  class UploadResult
    property file_uri : String?
    property file_path : String?
    property errors : Hash(String, Array(String))

    def initialize(@file_uri = nil, @file_path = nil, @errors = Hash(String, Array(String)).new)
    end

    # Returns `true` if upload was successful.
    #
    def valid?
      @errors.empty?
    end

    # Adds an error.
    #
    def add_error(field : String, message : String)
      @errors[field] ||= [] of String
      @errors[field] << message
    end
  end

  # Result of deleting a file.
  #
  class DeletionResult
    property deleted_paths : Array(String)
    property errors : Hash(String, Array(String))

    def initialize(@deleted_paths = [] of String, @errors = Hash(String, Array(String)).new)
    end

    # Returns `true` if deletion was successful.
    #
    def success?
      @errors.empty?
    end

    # Adds an error.
    #
    def add_error(field : String, message : String)
      @errors[field] ||= [] of String
      @errors[field] << message
    end
  end

  # Handles uploading a file.
  #
  # Orchestrates the entire upload process from validation through storage.
  #
  def self.upload(
    file : File,
    filename : String,
    actor_id : Int64,
    public_folder : String = Kemal.config.public_folder,
    max_size : Int64? = 5_242_880,
    host : String = Ktistec.host,
  ) : UploadResult
    UploadResult.new.tap do |result|
      file_size = file.size
      if file_size == 0
        result.add_error("file", "File cannot be empty")
      elsif max_size && file_size > max_size
        result.add_error("file", "File size exceeds maximum (#{max_size} bytes)")
      else
        directory, filename = generate_storage_path(actor_id, File.extname(filename))
        full_dir_path = File.join(public_folder, directory)
        full_file_path = File.join(full_dir_path, filename)
        begin
          Dir.mkdir_p(full_dir_path)
          if file.responds_to?(:path)
            File.chmod(file.path, 0o644)
            FileUtils.mv(file.path, full_file_path)
          else
            File.write(full_file_path, file.gets_to_end)
            File.chmod(full_file_path, 0o644)
          end
          result.file_path = "/#{directory}/#{filename}"
          result.file_uri = "#{host}#{result.file_path}"
        rescue ex : File::Error
          message = "Failed to upload: #{ex.message}"
          Log.warn { message }
          result.add_error("file", message)
        end
      end
    end
  end

  # Handles deleting a file.
  #
  # Removes the uploaded file and cleans up empty parent directories.
  #
  def self.delete(
    path : String,
    actor_id : Int64,
    public_folder : String = Kemal.config.public_folder,
  ) : DeletionResult
    DeletionResult.new.tap do |result|
      if !authorize(path, actor_id)
        result.add_error("file", "File does not belong to actor")
      else
        full_file_path = File.join(public_folder, path)
        begin
          if File.exists?(full_file_path)
            File.delete(full_file_path)
            result.deleted_paths << full_file_path
            Log.debug { "Deleted upload: #{full_file_path}" }
            uploads_root = File.join(public_folder, "uploads")
            cleanup_empty_directories(File.dirname(full_file_path), uploads_root, result)
          end
        rescue ex : File::Error
          message = "Failed to delete #{path}: #{ex.message}"
          Log.warn { message }
          result.add_error("file", message)
        end
      end
    end
  end

  # Validates that an actor owns a specific upload.
  #
  def self.authorize(file_path : String, actor_id : Int64) : Bool
    components = parse_path_components(file_path)
    return false unless components

    components[:actor_id] == actor_id
  end

  # Generates storage directory and filename.
  #
  private def self.generate_storage_path(actor_id : Int64, extension : String) : Tuple(String, String)
    uuid_parts = Tuple(String, String, String).from(UUID.random.to_s.split("-")[0..2])
    directory = File.join("uploads", *uuid_parts)
    filename = "#{actor_id}#{extension}"
    {directory, filename}
  end

  # Parses and validates path components.
  #
  # Returns path components and actor ID if valid, `nil` otherwise.
  #
  private def self.parse_path_components(path : String) : NamedTuple(p1: String, p2: String, p3: String, filename: String, actor_id: Int64)?
    if (match = path.match(/^\/uploads\/([a-z0-9-]+)\/([a-z0-9-]+)\/([a-z0-9-]+)\/(([0-9]+)(\.[a-zA-Z0-9_-]+)?)$/))
      p1, p2, p3, filename, id_str = match[1], match[2], match[3], match[4], match[5]
      if (actor_id = id_str.to_i64?)
        {p1: p1, p2: p2, p3: p3, filename: filename, actor_id: actor_id}
      end
    end
  end

  # Recursively removes empty directories within `uploads_root`.
  #
  private def self.cleanup_empty_directories(dir : String, uploads_root : String, result : DeletionResult)
    if dir.starts_with?(uploads_root) && dir != uploads_root && Dir.empty?(dir)
      Dir.delete(dir)
      result.deleted_paths << dir
      Log.debug { "Removed empty directory: #{dir}" }
      cleanup_empty_directories(File.dirname(dir), uploads_root, result)
    end
  rescue ex : File::Error
    message = "Failed to remove directory #{dir}: #{ex.message}"
    Log.warn { message }
    result.add_error("directory", message)
  end
end
