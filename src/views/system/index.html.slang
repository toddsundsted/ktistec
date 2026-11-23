crystal:
  no_defaults = env.params.query.fetch_all("filters").includes?("no-defaults")
h1 Log Levels
p
  | The default log level is
  span.blue< = ::Log.default
  | .
form.feed-controls.ui.secondary.pointing.menu method="GET" action=system_path data-controller="submit-on-change"
  .item
    .ui.mini.toggle.checkbox
      input#system-no-defaults type="checkbox" name="filters" value="no-defaults" data-action="change->submit-on-change#change" checked=no_defaults
      label for="system-no-defaults" Hide defaulted
- if sources.empty?
  p No log levels differ from the default.
- else
  form.ui.form method="POST" action=system_path
    = authenticity_token(env)
    - sources.sort.each do |source|
      .field
        h2 = source
      .inline.fields.unstackable
        - severity = log_levels[source]?.try(&.severity)
        .field
          .ui.radio.checkbox
            input id="#{source}-default" type="radio" name=source value="" checked=!!severity.nil?
            label for="#{source}-default" Default
        .field
          .ui.radio.checkbox
            input id="#{source}-trace" type="radio" name=source value="Trace" checked=!!severity.try(&.trace?)
            label for="#{source}-trace" Trace
        .field
          .ui.radio.checkbox
            input id="#{source}-debug" type="radio" name=source value="Debug" checked=!!severity.try(&.debug?)
            label for="#{source}-debug" Debug
        .field
          .ui.radio.checkbox
            input id="#{source}-info" type="radio" name=source value="Info" checked=!!severity.try(&.info?)
            label for="#{source}-info" Info
        .field
          .ui.radio.checkbox
            input id="#{source}-notice" type="radio" name=source value="Notice" checked=!!severity.try(&.notice?)
            label for="#{source}-notice" Notice
        .field
          .ui.radio.checkbox
            input id="#{source}-warn" type="radio" name=source value="Warn" checked=!!severity.try(&.warn?)
            label for="#{source}-warn" Warn
        .field
          .ui.radio.checkbox
            input id="#{source}-error" type="radio" name=source value="Error" checked=!!severity.try(&.error?)
            label for="#{source}-error" Error
        .field
          .ui.radio.checkbox
            input id="#{source}-fatal" type="radio" name=source value="Fatal" checked=!!severity.try(&.fatal?)
            label for="#{source}-fatal" Fatal
    .field
      = submit_button
