nav.ui.secondary.pagination.menu
  - if page > 1
    - query["page"] = (page - 1).to_s
    a.item href="?#{query}" : i.angle.double.left.icon
  - if collection.more?
    - query["page"] = (page + 1).to_s
    a.item href="?#{query}" : i.angle.double.right.icon
