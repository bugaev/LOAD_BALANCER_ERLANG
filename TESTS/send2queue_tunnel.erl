#!/usr/bin/env escript
%%! -smp enable

main(CommandForSubmission) ->
%%    net_kernel:start([SessionName, shortnames]),
    %CommandStr = string:join(bvvfile:escape(bvvfile:escape(CommandForSubmission)), ","),
    %CommandStr = string:join(bvvfile:escape(CommandForSubmission), ","),
    EscapedCommand = lists:map(fun bvvfile:escape/1, CommandForSubmission),
    CommandStr = string:join(EscapedCommand, " "),
    io:format("Submitting command ~p~n", [CommandStr]),
    io:format("With Cookie: ~s", [bvvfile:get_cookie()]),
    SomeHostInNet = "localhost", % to make it runnable on one machine
    %SomeHostInNet = "jupiter.wustl.edu", % to make it runnable on one machine
    case gen_tcp:connect(SomeHostInNet, 5000, [list, {packet, 0}]) of
        {ok, Sock} ->
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), CommandStr]),
            ok = gen_tcp:close(Sock);
        {error, econnrefused} ->
            io:format("Error: couldn't connect to queueing server.\n"),
            %exit(econnrefused)
            halt(1)
    end.
