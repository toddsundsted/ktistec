require "../framework/model"
require "./account"

# The last time something was visited, checked or changed.
#
class LastTime
  include Ktistec::Model
  include Ktistec::Model::Common

  @@table_name = "last_times"

  @[Persistent]
  @[Insignificant]
  property timestamp : Time { Time.utc }

  @[Persistent]
  property name : String
  validates(name) do
    if !name.presence
      "can't be blank"
    elsif (instance = self.class.where(name: name, account_id: account_id).first?) && instance.id != self.id
      "already exists: #{name}"
    end
  end

  @[Persistent]
  property account_id : Int64?
  belongs_to account
  validates(account) { "can't find Account with id=#{account_id}" if account_id && !account? }
end
