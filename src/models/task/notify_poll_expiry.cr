require "../task"
require "../activity_pub/object/question"
require "../relationship/content/notification/poll/expiry"

class Task
  class NotifyPollExpiry < Task
    belongs_to question, class_name: ActivityPub::Object::Question, foreign_key: subject_iri, primary_key: iri
    validates(question) { "missing: #{subject_iri}" unless question? }

    def perform
      return unless question?
      question.voters.each do |voter|
        next if Relationship::Content::Notification::Poll::Expiry.find?(owner: voter, question: question)
        Relationship::Content::Notification::Poll::Expiry.new(owner: voter, question: question).save
      end
    end
  end
end
