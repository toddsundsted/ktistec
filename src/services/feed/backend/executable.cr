require "../backend"
require "./executable/exchange"

class Feed
  abstract class Backend
    # A judge that is an executable file.
    #
    # A judge may declare settings in its first lines, after any
    # comment syntax:
    #
    #     # ktistec: batch-size=10
    #     # ktistec: revision=2
    #
    # Settings are read when the judge is created.
    #
    class Executable < Backend
      Log = ::Log.for(self)

      class_property deadline : Time::Span = 5.minutes

      class_property grace : Time::Span = 10.seconds

      FRONT_MATTER_LINES = 10

      FRONT_MATTER = /\bktistec: ([a-z][a-z-]*)=(\S+)/

      getter path : String

      @batch_size : Int32

      @revision : String

      # Creates the judge.
      #
      # A `revision` overrides the one the judge declares.
      #
      def initialize(@path : String, revision : String? = nil)
        front_matter = read_front_matter
        @batch_size = batch_size_from(front_matter)
        @revision = revision || front_matter["revision"]? || ""
      end

      def judge(feed : ::Feed, objects : Array(ActivityPub::Object)) : Array(Judgment | Failure)
        file = File.tempname("ktistec", "exchange")
        Exchange.write(file, feed, objects)
        status = run(file)
        raise TransientError.new("judge #{path} exited with #{status}") unless status.success?
        answers = Exchange.read(file)
        objects.map do |object|
          answers[object.iri]? || Failure.new(:transient, "judge did not answer")
        end
      ensure
        File.delete?(file) if file
      end

      def validate_params(params : Hash(String, JSON::Any)) : Array(String)
        [] of String
      end

      def revision(params : Hash(String, JSON::Any)) : String
        @revision
      end

      def cost(params : Hash(String, JSON::Any)) : Cost
        Cost.new(batch_size: @batch_size)
      end

      private def read_front_matter : Hash(String, String)
        front_matter = {} of String => String
        File.open(path) do |file|
          FRONT_MATTER_LINES.times do
            break unless (line = file.gets) && line.valid_encoding?
            if (match = FRONT_MATTER.match(line))
              front_matter[match[1]] = match[2]
            end
          end
        end
        front_matter
      end

      private def batch_size_from(front_matter : Hash(String, String)) : Int32
        if (value = front_matter["batch-size"]?)
          if (batch_size = value.to_i?) && batch_size > 0
            batch_size
          else
            Log.warn { "judge #{path} declares a malformed batch size: #{value}" }
            1
          end
        else
          1
        end
      end

      # Runs the judge until it exits or runs past the deadline.
      #
      private def run(file : String) : Process::Status
        process = Process.new(
          path, [file],
          clear_env: true,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe,
        )
        logged = Channel(Nil).new(2)
        spawn { log(process.output, logged) { |line| Log.info &.emit(line, judge: path) } }
        spawn { log(process.error, logged) { |line| Log.warn &.emit(line, judge: path) } }
        exited = Channel(Process::Status).new(1)
        spawn do
          # `wait` closes the pipes, so log everything first
          2.times { logged.receive }
          exited.send(process.wait)
        end
        select
        when status = exited.receive
          status
        when timeout(self.class.deadline)
          stop(process, exited)
          raise TransientError.new("judge #{path} ran past the deadline")
        end
      end

      private def log(io : IO, logged : Channel(Nil), &) : Nil
        while (line = io.gets)
          yield line
        end
      rescue IO::Error
        # closed while stopping
      ensure
        logged.send(nil)
      end

      private def stop(process : Process, exited : Channel(Process::Status)) : Nil
        signal(process, graceful: true)
        select
        when exited.receive
        when timeout(self.class.grace)
          signal(process, graceful: false)
          process.close
          exited.receive
        end
      end

      private def signal(process : Process, graceful : Bool) : Nil
        process.terminate(graceful: graceful)
      rescue RuntimeError
        # already exited
      end
    end
  end
end
