require "../backend"
require "./executable/exchange"

class Feed
  abstract class Backend
    # A judge that is an executable file.
    #
    class Executable < Backend
      Log = ::Log.for(self)

      class_property deadline : Time::Span = 5.minutes

      class_property grace : Time::Span = 10.seconds

      getter path : String

      def initialize(@path : String)
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
        ""
      end

      def cost(params : Hash(String, JSON::Any)) : Cost
        Cost.new(batch_size: 1)
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
