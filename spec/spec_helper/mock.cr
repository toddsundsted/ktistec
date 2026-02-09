class MockDeliverTask < Task::Deliver
  class_property schedule_called_count : Int32 = 0
  class_property last_sender : ActivityPub::Actor?
  class_property last_activity : ActivityPub::Activity?

  def self.reset!
    self.schedule_called_count = 0
    self.last_sender = nil
    self.last_activity = nil
  end

  def initialize(sender : ActivityPub::Actor, activity : ActivityPub::Activity)
    super(sender: sender, activity: activity)
    self.class.last_sender = sender
    self.class.last_activity = activity
  end

  def schedule(next_attempt_at = nil)
    self.class.schedule_called_count += 1
    # don't save to database
    self
  end
end

class MockReceiveTask < Task::Receive
  class_property schedule_called_count : Int32 = 0
  class_property last_receiver : ActivityPub::Actor?
  class_property last_activity : ActivityPub::Activity?
  class_property last_deliver_to : Array(String)?

  def self.reset!
    self.schedule_called_count = 0
    self.last_receiver = nil
    self.last_activity = nil
    self.last_deliver_to = nil
  end

  def initialize(receiver : ActivityPub::Actor, activity : ActivityPub::Activity, deliver_to : Array(String)? = nil)
    super(receiver: receiver, activity: activity)
    self.deliver_to = deliver_to if deliver_to
    self.class.last_receiver = receiver
    self.class.last_activity = activity
    self.class.last_deliver_to = deliver_to
  end

  def schedule(next_attempt_at = nil)
    self.class.schedule_called_count += 1
    # don't save to database
    self
  end
end

class MockHandleFollowRequestTask < Task::HandleFollowRequest
  class_property schedule_called_count : Int32 = 0
  class_property last_recipient : ActivityPub::Actor?
  class_property last_activity : ActivityPub::Activity::Follow?

  def self.reset!
    self.schedule_called_count = 0
    self.last_recipient = nil
    self.last_activity = nil
  end

  def initialize(recipient : ActivityPub::Actor, activity : ActivityPub::Activity::Follow)
    super(recipient: recipient, activity: activity)
    self.class.last_recipient = recipient
    self.class.last_activity = activity
  end

  def schedule(next_attempt_at = nil)
    self.class.schedule_called_count += 1
    # don't save to database
    self
  end
end
