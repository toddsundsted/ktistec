require "digest/sha256"
require "kemal"

# Cache-busting for static assets.
#
# A digest of an asset's contents is appended to its path as a query
# parameter (see `Utils::Paths.asset_path`).
#
module Ktistec::Assets
  @@mutex = Mutex.new

  @@digests = Hash(String, Tuple(Time, String)).new

  # Returns a digest of the asset at request path *path*.
  #
  # Returns `nil` if the asset does not exist.
  #
  # Digests are cached. A cached digest is recomputed when the
  # asset's modification time changes, so assets rebuilt under a
  # running server are picked up without a restart.
  #
  def self.digest?(path : String) : String?
    return if path.includes?("..")
    file_path = File.join(Kemal.config.public_folder, path)
    return unless (info = File.info?(file_path)) && info.file?
    modification_time = info.modification_time
    @@mutex.synchronize do
      cached = @@digests[file_path]?
      if cached && cached.first == modification_time
        cached.last
      else
        begin
          digest = Digest::SHA256.new.file(file_path).hexfinal[0, 8]
        rescue File::Error
          next
        end
        @@digests[file_path] = {modification_time, digest}
        digest
      end
    end
  end
end
