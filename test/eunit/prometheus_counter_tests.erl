-module(prometheus_counter_tests).

-include_lib("eunit/include/eunit.hrl").

prometheus_format_test_() ->
  {foreach,
   fun prometheus_eunit_common:start/0,
   fun prometheus_eunit_common:stop/1,
   [fun test_registration/1,
    fun test_errors/1,
    fun test_int/1,
    fun test_double/1]}.

test_registration(_)->
  Name = http_requests_total,
  Spec = [{name, Name}, {help, "Http request count"}],
  [?_assertEqual(true,
                 prometheus_counter:declare(Spec)),
   ?_assertEqual(false,
                 prometheus_counter:declare(Spec)),
   ?_assertError({mf_already_exists, {default, Name}, "Consider using declare instead."},
                 prometheus_counter:new(Spec))].

test_errors(_) ->
  prometheus_counter:new([{name, http_requests_total}, {help, "Http request count"}]),
  [%% basic name/labels/help validations test, lets hope new is using extract_common_params
   ?_assertError({invalid_metric_name, 12, "metric name is not a string"}, prometheus_counter:new([{name, 12}, {help, ""}])),
   ?_assertError({invalid_metric_labels, 12, "not list"}, prometheus_counter:new([{name, "qwe"}, {labels, 12}, {help, ""}])),
   ?_assertError({invalid_metric_help, 12, "metric help is not a string"}, prometheus_counter:new([{name, "qwe"}, {help, 12}])),
   %% counter specific errors
   ?_assertError({invalid_value, -1, "Counters accept only non-negative values"}, prometheus_counter:inc(http_requests_total, -1)),
   ?_assertError({invalid_value, 1.5, "inc accepts only integers"}, prometheus_counter:inc(http_requests_total, 1.5)),
   ?_assertError({invalid_value, "qwe", "inc accepts only integers"}, prometheus_counter:inc(http_requests_total, [], "qwe")),
   ?_assertError({invalid_value, -1, "Counters accept only non-negative values"}, prometheus_counter:dinc(http_requests_total, -1)),
   ?_assertError({invalid_value, "qwe", "dinc accepts only numbers"}, prometheus_counter:dinc(http_requests_total, [], "qwe"))
  ].

test_int(_) ->
  prometheus_counter:new([{name, http_requests_total}, {labels, [method]}, {help, "Http request count"}]),
  prometheus_counter:inc(http_requests_total, [get]),
  prometheus_counter:inc(http_requests_total, [get], 3),
  Value = prometheus_counter:value(http_requests_total, [get]),
  prometheus_counter:reset(http_requests_total, [get]),
  RValue = prometheus_counter:value(http_requests_total, [get]),
  [?_assertEqual(4, Value),
   ?_assertEqual(0, RValue)].


test_double(_) ->
  prometheus_counter:new([{name, http_requests_total}, {help, "Http request count"}]),
  prometheus_counter:dinc(http_requests_total),
  prometheus_counter:dinc(http_requests_total, 3.5),
  timer:sleep(10), %% dinc is async so lets make sure gen_server processed our increment request
  Value = prometheus_counter:value(http_requests_total),
  prometheus_counter:reset(http_requests_total),
  RValue = prometheus_counter:value(http_requests_total),
  [?_assertEqual(4.5, Value),
   ?_assertEqual(0, RValue)].
