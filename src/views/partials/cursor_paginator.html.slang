crystal:
  _prev = collection.cursor_start
  _next = collection.cursor_end && collection.more?
  temp = query.dup
  temp.delete_all("max_id")
  temp.delete_all("min_id")
- if _prev || _next
  nav.ui.secondary.pagination.menu
    - if _prev
      - temp["min_id"] = collection.cursor_start.to_s
      a.item href="?#{temp}" target="_top"
        i.angle.double.left.icon
    - if _next
      - temp.delete_all("min_id")
      - temp["max_id"] = collection.cursor_end.to_s
      a.item href="?#{temp}" target="_top"
        i.angle.double.right.icon
