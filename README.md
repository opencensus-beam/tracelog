tracelog
=====

A logging handler that can transforms structured logs into opencensus distributed tracing spans

Configuration
-------------

This library only works with logs that can be paired up with one that 'starts' and one that 'stops' a given event. For example, the following configuration:

```erlang
[
  {kernel, [
     {logger, [
         {handler, opencensus, tracelog_handler,
          #{open_close_pairs => [
                % {key name, {open val, close val}}
                {type, {command, event}},
                {part, {request, response}},
                {trace, {start, stop}}
            ],
            name_keys => [what, span]
           }
         }
     ]},
     {logger_level, info}
  ]},
  ...
].
```

This means that any log that has any of the keys/values below will work:

```erlang
%% any log level works
?LOG_INFO(#{... type => command, ...})  % opens the span
?LOG_INFO(#{... type => event, ...})    % closes the span

?LOG_INFO(#{... part => request, ...})  % opens the span
?LOG_INFO(#{... part => response, ...})    % closes the span

?LOG_INFO(#{... trace => start, ...})  % opens the span
?LOG_INFO(#{... trace => stop, ...})    % closes the span
```

By default, only `{trace, {start, stop}}` is configured. The list of trace types given is scanned in order, so the most frequently expected keys should be put first.

The name of the span will be defined by any of the `name_keys` arguments, in the precedence given by the list. If no matching label fits, the handler defaults to using the calling function name defined by the `mfa` meta value inserted by the `logger` library. If no such label nor `mfa` value is available, the name `undefined` is used by the span.

Notes
-----

This log handler does not output any log lines, it only forwards calls to opencensus. You still have to carry the opencensus trace context across processes of services yourself; this handler only makes it easier to reuse logs as spans to provide detailed tracing views.
