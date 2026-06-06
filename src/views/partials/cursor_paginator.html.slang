crystal:
  _prev = collection.cursor_start && collection.has_prev?
  _next = collection.cursor_end && collection.has_next?
  temp = query.dup
  temp.delete_all("max_id")
  temp.delete_all("max-id")
  temp.delete_all("min_id")
  temp.delete_all("min-id")
- if _prev || _next
  nav.ui.secondary.pagination.menu
    - if _prev
      - temp["min-id"] = collection.cursor_start.to_s
      a.item href=Utils::Paths.query_path(temp) target="_top"
        i.angle.double.left.icon
    - if _next
      - temp.delete_all("min-id")
      - temp["max-id"] = collection.cursor_end.to_s
      a.item href=Utils::Paths.query_path(temp) target="_top"
        i.angle.double.right.icon
