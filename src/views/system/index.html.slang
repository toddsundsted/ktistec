h1 Log Levels
p
  | The default log level is
  span.blue< = Ktistec::LogLevel.default
  | .
form.ui.form method="POST" action=system_path
  == authenticity_token(env)
  - sources.sort.each do |source|
    .field
      h2 = source
    .inline.fields
      - severity = log_levels[source]?.try(&.severity)
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="" checked=!!severity.nil?
          label Default
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Trace" checked=!!severity.try(&.trace?)
          label Trace
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Debug" checked=!!severity.try(&.debug?)
          label Debug
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Info" checked=!!severity.try(&.info?)
          label Info
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Notice" checked=!!severity.try(&.notice?)
          label Notice
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Warn" checked=!!severity.try(&.warn?)
          label Warn
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Error" checked=!!severity.try(&.error?)
          label Error
      .field
        .ui.radio.checkbox
          input type="radio" name=source value="Fatal" checked=!!severity.try(&.fatal?)
          label Fatal
  .field
    == submit_button
br.transition.hidden
