crystal:
  temp = query.dup
nav.ui.secondary.pagination.menu
  - if page > 1
    - temp["page"] = (page - 1).to_s
    a.item href="?#{temp}" : i.angle.double.left.icon
  - if collection.more?
    - temp["page"] = (page + 1).to_s
    a.item href="?#{temp}" : i.angle.double.right.icon
