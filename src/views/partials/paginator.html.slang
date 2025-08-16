crystal:
  _prev = page > 1
  _next = collection.more?
  temp = query.dup
- if _prev || _next
  nav.ui.secondary.pagination.menu
    - if _prev
      - temp["page"] = (page - 1).to_s
      a.item href="?#{temp}" target="_top"
        i.angle.double.left.icon
    - if _next
      - temp["page"] = (page + 1).to_s
      a.item href="?#{temp}" target="_top"
        i.angle.double.right.icon
