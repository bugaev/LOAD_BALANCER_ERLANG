#!/usr/bin/env escript
%%! -smp enable -pa /faculty/bugaev/PROGS/ERLANG -foo yeah

parse_opt(Cmd, Dict)->
    parse_opt(Cmd, Dict, dict:new(), []).

parse_opt(Cmd, Dict, Parsed, CurOpt) ->
    %io:format("(args:)\n~p\n~p\n~p\n(end args)\n", [Cmd, Parsed, CurOpt]),
    case Cmd of
        [Arg | Tail] ->
            %io:format("Arg:~p\n", [Arg]),
            Option =
            case CurOpt of
                [] ->
                    case lists:keyfind(Arg, 1, Dict) of
                        false -> nooption;
                        {_, Value} -> Value
                    end;
                _ -> 
                    CurOpt
            end,

            ParsedUpdated =
            case Option of
                nooption ->
                    %[{nooption, Arg} | Parsed];
                    dict:append(nooption, Arg, Parsed);
                _ ->
                    case CurOpt of
                        [] ->
                            Parsed;
                        _ ->
                            %[{Option, Arg} | Parsed]
                            dict:append(Option, Arg, Parsed)
                    end
            end,
            CurOptUpdated =
            case CurOpt of
                [] when Option /= nooption ->
                    Option;
                _ ->
                    []
            end,

            parse_opt(Tail, Dict, ParsedUpdated, CurOptUpdated);
        [] ->
            Parsed
    end.

main(QueueCommand) ->
%%    net_kernel:start([SessionName, shortnames]),
    %CommandStr = string:join(bvvfile:escape(bvvfile:escape(QueueCommand)), ","),
    %CommandStr = string:join(bvvfile:escape(QueueCommand), ","),
    Dict = [{"-o", output}, {"-q", queue}, {"-e", errout}],
    {ok, Dir0} = file:get_cwd(),
    %Tmp = init:get_argument(a),
    %ParsedOpts = dict:from_list(parse_opt(QueueCommand, Dict)),
    ParsedOpts = parse_opt(QueueCommand, Dict),
    [io:format("Key: ~p; Val: ~p\n", [Key, dict:fetch(Key, ParsedOpts)]) || Key <- dict:fetch_keys(ParsedOpts)],
    %io:format("Parsed Cmd:~p\n", [ParsedOpts]),
    %halt(1),
    %io:format("Output: ~p\n", [escript:script_arg1()]),
    CommandForSubmission = dict:fetch(nooption, ParsedOpts),
    EscapedCommand = lists:map(fun bvvfile:escape/1, CommandForSubmission),
    CommandStr = string:join(EscapedCommand, " "),
    Queue = dict:fetch(queue, ParsedOpts),
    ErrOut0 = dict:fetch(errout, ParsedOpts),
    Output0 = dict:fetch(output, ParsedOpts),
    Dir = re:replace(Dir0, "^/nfshome", "/faculty", [global, {return, list}]),
    Output = 
    if
        hd(Output0) /= $/ ->
            Dir ++ "/" ++ Output0;
        true ->
            re:replace(Output0, "^/nfshome", "/faculty", [global, {return, list}])
    end,
    ErrOut =
    if
        hd(ErrOut0) /= $/ ->
            Dir ++ "/" ++ ErrOut0;
        true ->
            re:replace(ErrOut0, "^/nfshome", "/faculty", [global, {return, list}])
    end,

    io:format("Submitting command ~p~n", [CommandStr]),
    io:format("With Cookie: ~s", [bvvfile:get_cookie()]),
    io:format("Working Directory: ~s\n", [Dir]),
    io:format("Queue: ~s\n", [Queue]),
    io:format("Output: ~s\n", [Output]),
    io:format("ErrOut: ~s\n", [ErrOut]),
    %SomeHostInNet = "localhost", % to make it runnable on one machine
    SomeHostInNet = "jupiter.local", % to make it runnable on one machine
    case gen_tcp:connect(SomeHostInNet, 5679, [list, {packet, 4}, {active, false}]) of
        {ok, Sock} ->
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), ErrOut]),
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), Output]),
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), Queue]),
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), Dir]),
            ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), CommandStr]),

            case gen_tcp:recv(Sock, 0) of
                {ok, B} ->
                    ok = gen_tcp:close(Sock),
                    %io:format("Submitted job: ~p\n", [hd(B)]);
                    io:format("Submitted job: ~p\n", [B]);
                {error, closed} ->
                    io:format("Error: disconnected from queueing server.\n")
            end;

        {error, econnrefused} ->
            io:format("Error: couldn't connect to queueing server.\n"),
            %exit(econnrefused)
            halt(1)
    end.
