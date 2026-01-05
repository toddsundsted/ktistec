- content_for "title" do
  | Tasks
h1 Tasks
- if running_count > 0
  .ui.red.icon.message
    .content
      .header Tasks Running
      p #{pluralize(running_count, "task")} currently running.
    a.ui.basic.tiny.right.floated.button href=Ktistec::ViewHelper.tasks_path
      i.refresh.icon
      | Refresh
- elsif scheduled_soon_count > 0
  .ui.yellow.icon.message
    .content
      .header Tasks Starting Soon
      p #{pluralize(scheduled_soon_count, "task")} scheduled to run within one minute.
    a.ui.basic.tiny.right.floated.button href=Ktistec::ViewHelper.tasks_path
      i.refresh.icon
      | Refresh
- else
  .ui.green.icon.message
    .content
      .header All Tasks Idle
      p No tasks are running or scheduled to start soon.
    a.ui.basic.tiny.right.floated.button href=Ktistec::ViewHelper.tasks_path
      i.refresh.icon
      | Refresh
- if tasks.empty?
  .ui.basic.very.padded.center.aligned.segment
    .ui.icon.header
      i.exclamation.icon
      | There are no scheduled tasks.
- else
  table.ui.small.compact.structured.celled.table
    - tasks.each do |task|
      - if (subject_iri = task.subject_iri.presence)
        tr
          td rowspan=2
            - if task.responds_to?(:path_to)
              a href=task.path_to = task.class
            - else
              = task.class
          td == wrap_link(subject_iri, include_scheme: true, length: 60, tag: :span)
        tr
          - if task.is_a?(Task::Fetch::Fetcher)
            td = fetch_task_status_line(task, detail: true)
          - else
            td = task_status_line(task, detail: true)
      - else
        tr
          td
            - if task.responds_to?(:path_to)
              a href=task.path_to = task.class
            - else
              = task.class
          - if task.is_a?(Task::Fetch::Fetcher)
            td = fetch_task_status_line(task, detail: true)
          - else
            td = task_status_line(task, detail: true)
br.transition.hidden
