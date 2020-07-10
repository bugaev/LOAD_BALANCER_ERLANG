-module(bvvfile).
-export([test/0, get_cookie/0, escape/1]).

for_each_line_in_file(Name, Proc, Mode, Accum0) ->
    {ok, Device} = file:open(Name, Mode),
    for_each_line(Device, Proc, Accum0).

for_each_line(Device, Proc, Accum) ->
    case io:get_line(Device, "") of
        eof  -> file:close(Device), Accum;
        Line -> NewAccum = Proc(Line, Accum),
                    for_each_line(Device, Proc, NewAccum)
    end.

accum_lines(Line, {Count, X}) ->
    {Count + 1, [Line | X]}.

    get_cookie() ->
    Home = os:getenv("HOME") ++ "/.erlang.cookie",
    {_, FileContReversed} = for_each_line_in_file(Home, fun accum_lines/2, [read], {0, []}),
    hd(FileContReversed).
   
% public
escape(String) ->
    escape(String, []).

% internal
escape([], Acc) ->
    lists:reverse(Acc);
escape([$\s | Rest], Acc) ->
    %escape(Rest, lists:reverse("\\ ", Acc));
    escape(Rest, lists:reverse("\ ", Acc));
escape([C | Rest], Acc) ->
    escape(Rest, [C | Acc]).

test() ->
    Home = os:getenv("HOME") ++ "/.erlang.cookie",
    {_, FileContReversed} = for_each_line_in_file(Home, fun accum_lines/2, [read], {0, []}),
    %{_, FileCont} = for_each_line_in_file("/home/guest/.erlang.cookie", fun accum_lines/2, [read], {0, []}),
    %{_, FileContReversed} = for_each_line_in_file("test_file.txt", fun accum_lines/2, [read], {0, []}),
    FileCont = lists:reverse(FileContReversed),
    io:format("~p\n", [FileCont]).
