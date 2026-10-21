require "file_utils"

require "../../../../src/services/feed/backend/executable"
require "../../../../src/models/feed"

require "../../../spec_helper/base"
require "../../../spec_helper/factory"

Spectator.describe Feed::Backend::Executable do
  setup_spec

  let(path) { File.tempname("ktistec", "judge") }

  after_each { File.delete?(path) }

  subject { described_class.new(path) }

  def write_judge(script)
    File.write(path, "#!/bin/sh\n#{script}\n")
    File.chmod(path, 0o755)
  end

  describe "#judge" do
    let_build(:feed, name: "Test", backend: "summarize")
    let_build(:object)

    it "deletes the exchange file" do
      write_judge("exit 0")
      expect { subject.judge(feed, [object]) }.not_to change { Dir.glob(File.join(Dir.tempdir, "ktistec*exchange")).size }
    end

    context "given a judge that answers" do
      let(answers) { File.tempname("ktistec", "answers") }

      before_each do
        Feed::Backend::Executable::Exchange.write(answers, feed, [object])
        DB.open("sqlite3://#{answers}", &.exec("INSERT INTO answers (iri, included) VALUES (?, 1)", object.iri))
        write_judge(%(cp "#{answers}" "$1"))
      end

      after_each { File.delete?(answers) }

      it "returns the judge's answers" do
        expect(subject.judge(feed, [object])).to eq([Feed::Backend::Judgment.new(included: true)])
      end
    end

    context "given a judge that doesn't answer" do
      before_each { write_judge("exit 0") }

      it "returns a transient failure" do
        expect(subject.judge(feed, [object]).first.as(Feed::Backend::Failure).kind).to eq(Feed::Backend::Failure::Kind::Transient)
      end
    end

    context "given a judge that exits with an error" do
      before_each { write_judge("exit 1") }

      it "fails transiently" do
        expect { subject.judge(feed, [object]) }.to raise_error(Feed::Backend::TransientError)
      end
    end

    context "given a judge that runs past the deadline" do
      around_each do |proc|
        deadline = described_class.deadline
        described_class.deadline = 10.milliseconds
        begin
          proc.call
        ensure
          described_class.deadline = deadline
        end
      end

      before_each { write_judge("exec sleep 10") }

      it "fails transiently" do
        expect { subject.judge(feed, [object]) }.to raise_error(Feed::Backend::TransientError)
      end
    end
  end

  describe "#validate_params" do
    context "given a judge that declares a required integer param" do
      before_each { write_judge("# ktistec: param=minimum type=integer required") }

      it "accepts an integer" do
        expect(subject.validate_params({"minimum" => JSON::Any.new(5_i64)})).to be_empty
      end

      it "rejects a string" do
        expect(subject.validate_params({"minimum" => JSON::Any.new("5")})).to eq(["minimum must be an integer"])
      end

      it "rejects a missing value" do
        expect(subject.validate_params({} of String => JSON::Any)).to eq(["minimum is required"])
      end
    end

    context "given a judge that declares a param without a type" do
      before_each { write_judge("# ktistec: param=label") }

      it "accepts a missing value" do
        expect(subject.validate_params({} of String => JSON::Any)).to be_empty
      end

      it "rejects an integer" do
        expect(subject.validate_params({"label" => JSON::Any.new(5_i64)})).to eq(["label must be a string"])
      end
    end

    context "given a judge that declares a param of an unknown type" do
      before_each { write_judge("# ktistec: param=minimum type=float required") }

      it "rejects the param" do
        expect(subject.validate_params({"minimum" => JSON::Any.new(5_i64)})).to eq(["minimum is a malformed param"])
      end
    end
  end

  describe "#revision" do
    context "given a judge that declares a revision" do
      before_each { write_judge("# ktistec: revision=2") }

      it "returns the revision" do
        expect(subject.revision({} of String => JSON::Any)).to eq("2")
      end
    end
  end

  describe "#cost" do
    context "given a judge that declares a batch size" do
      before_each { write_judge("# ktistec: batch-size=10") }

      it "returns the batch size" do
        expect(subject.cost({} of String => JSON::Any).batch_size).to eq(10)
      end
    end

    context "given a judge that declares a batch size of 0" do
      before_each { write_judge("# ktistec: batch-size=0") }

      it "returns a batch size of 1" do
        expect(subject.cost({} of String => JSON::Any).batch_size).to eq(1)
      end
    end

    context "given a compiled judge" do
      before_each do
        File.write(path, Bytes[0x7f, 0x45, 0x4c, 0x46, 0xff, 0x0a])
        File.chmod(path, 0o755)
      end

      it "returns a batch size of 1" do
        expect(subject.cost({} of String => JSON::Any).batch_size).to eq(1)
      end
    end
  end
end
