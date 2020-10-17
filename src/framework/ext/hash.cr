class Hash
  def presence
    self if !empty?
  end
end
