struct HTTP::Params
  def presence
    self if !empty?
  end
end
