module ViewSpecHelper
  # The membership rows (`from_iri`, `to_iri`, `position`).
  #
  def selected(key = nil)
    query, args = subject.membership(key)
    Ktistec.database.query_all(query, args: args, as: {String, String, Time})
  end

  # The member `to_iri`s.
  #
  def selected_iris(key = nil)
    selected(key).map { |row| row[1] }.to_set
  end

  # The predicate matches among the stored rows.
  #
  def scoped_rows(key)
    predicate, args = subject.stored_scope(key)
    Ktistec.database.query_all(
      "SELECT to_iri FROM relationships WHERE type = ? AND (#{predicate})",
      args: Array(DB::Any){subject.type} + args, as: String,
    ).to_set
  end
end
