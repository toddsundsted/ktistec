require "../task"
require "./mixins/singleton"
require "../account"
require "../session"

class Task
  # Runs scripts.
  #
  class RunScripts < Task
    include Singleton
    include ConcurrentTask

    Log = ::Log.for(self)

    private def make_channel(io : IO) : Channel
      Channel(String).new.tap do |channel|
        spawn name: "run-scripts-#{channel.object_id}" do
          while (line = io.gets)
            channel.send(line)
          end
        rescue IO::Error
          # ignore
        ensure
          channel.close
        end
      end
    end

    PATH = File.join("etc", "scripts")

    def perform
      account = Account.all.first
      session = Session.new(account).save
      jwt = session.generate_jwt
      Dir.new(PATH).each_child do |script|
        file = File.join(PATH, script)
        info = File.info(file)
        if info.file? && info.permissions.owner_execute?
          Log.with_context(script: script) do
            env = {
              "API_KEY" => jwt,
              "KTISTEC_HOST" => Ktistec.host,
              "KTISTEC_NAME" => Ktistec.name,
              "USERNAME" => account.username,
            }
            Process.run(file, env: env, clear_env: true) do |process|
              output = make_channel(process.output)
              error = make_channel(process.error)
              loop do
                select
                when line = output.receive
                  Log.info { line }
                when line = error.receive
                  Log.warn { line }
                when timeout(60.seconds)
                  Log.error { "timeout exceeded without output" }
                  process.terminate
                  break
                end
              end
            rescue Channel::ClosedError
              # done
            end
          end
        end
      rescue File::NotFoundError
        # file was removed while processing
      end
    rescue File::NotFoundError
      # directory does not exist
    ensure
      self.next_attempt_at = 1.hour.from_now
    end
  end
end
