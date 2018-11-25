-module(tracelog_handler).
-export([adding_handler/1, removing_handler/1, log/2]).

adding_handler(Config = #{}) ->
    PKList = maps:get(open_close_pairs, Config, [{trace, {start, stop}}]),
    Cfg = #{
        pair_keys => [K || {K, _} <- PKList], % preserve user-supplied order
        pairs => maps:from_list(PKList),
        name_keys => maps:get(name_keys, Config, [name])
    },
    NewConfig = maps:without(
        [open_close_pairs, name_keys],
        Config
    ),
    {ok, NewConfig#{config => Cfg}}.

removing_handler(_Config) ->
    ok.

log(#{meta := Meta, msg := {report, Msg}},
    #{config := #{pair_keys := Ks, pairs := Ps, name_keys := Ns}}) ->
    case matching_keywords(Ks, Ps, Msg) of
        {K, {Start, Stop}} ->
            case Msg of
                #{K := Start} ->
                    Span = span_name(Ns, Msg, Meta),
                    put({?MODULE, command, Span}, {seen, Stop}),
                    ocp:with_child_span(Span);
                #{K := End} ->
                    Span = span_name(Ns, Msg, Meta),
                    case get({?MODULE, command, Span}) of
                        undefined ->
                            ignore;
                        {seen, End} ->
                            erase({?MODULE, command, Span}),
                            ocp:finish_span()
                    end;
                _ ->
                    ok
            end;
        undefined ->
            ok
    end;
log(_, _) ->
    ignore.

matching_keywords([], _, _) ->
    undefined;
matching_keywords([H|T], Pairs, Msg) ->
    case Msg of
        #{H := _} ->
            {H, maps:get(H, Pairs)};
        _ ->
            matching_keywords(T, Pairs, Msg)
    end.

span_name([], _, #{mfa := MFA}) -> to_bin(MFA);
span_name([], _, _) -> <<"undefined">>;
span_name([H|T], Msg, Meta) ->
    case Msg of
        #{H := V} -> to_bin(V);
        _ -> span_name(T, Msg, Meta)
    end.

to_bin({M,F,A0}) ->
    A = if is_integer(A0) -> A0;
           is_list(A0) -> length(A0)
        end,
    <<(atom_to_binary(M, utf8))/binary, ":",
      (atom_to_binary(F, utf8))/binary, "/",
      (integer_to_binary(A))/binary>>;
to_bin(Str) when is_list(Str) ->
    unicode:characters_to_binary(Str);
to_bin(Atom) when is_atom(Atom) ->
    atom_to_binary(Atom, utf8).
