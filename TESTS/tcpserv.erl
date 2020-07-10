-module(tcpserv).
-export[s/0, tcp_server/0].

-define(MinFreeCores, 0.85).
-define(TZeroAppx, 10000). %milliseconds.
-define(TInfAppx, 5000). %milliseconds.
-define(TCpuUtil, 500). %milliseconds.

-record(runpars, {njobs, time, request_time, queue, host, cmd, dir, outputfilename, erroutfilename}).


%%%%%%%%%%%%%%%%%%%%%%%%%%  TCP SERVER  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
tcp_server() ->
    Prefix = bvvfile:get_cookie(),
    {ok, LSock} = gen_tcp:listen(5679, [list, {packet, 4}, {active,
                false}, {backlog, 999}]),
    NJobs = 1,
    tcp_server_loop(Prefix, LSock, NJobs).

tcp_server_loop(Prefix, LSock, NJobs) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    io:format("NJobs:~p\n", [NJobs]),
    {ok, Msg} = do_recv(Sock, [], 5),
    ok = gen_tcp:send(Sock, [integer_to_list(NJobs)]),
    ok = gen_tcp:close(Sock),
    MsgContent =
    try 
        lists:map(
            fun(X) ->
                SecretPhraseFound = lists:prefix(Prefix, X),
                case SecretPhraseFound of
                    true ->
                        ok;
                    false -> 
                        throw(not_authentic)
                end,
                lists:nthtail(length(Prefix), X)
            end,
            Msg)
    catch
        not_authentic ->
            not_authentic
    end,

    case MsgContent of
        not_authentic ->
            io:format("(tcp_server:) Message is NOT authentic!!!~n", []),
            NJobsUpdated = NJobs;
        _ ->
            NJobsUpdated = NJobs + 1
            %RunPars =
            %#runpars
            %{
            %    njobs = NJobs,
            %    request_time = now(),
            %    cmd = lists:nth(1, MsgContent),
            %    dir = lists:nth(2, MsgContent),
            %    queue = lists:nth(3, MsgContent),
            %    outputfilename = lists:nth(4, MsgContent),
            %    erroutfilename = lists:nth(5, MsgContent)
            %},
            %io:format("RunPars:~p\n", [RunPars])
    end,
    tcp_server_loop(Prefix, LSock, NJobsUpdated).

do_recv(Sock, BPrev, ParN) ->
    case ParN of
        0 ->
            {ok, BPrev};
        _ ->
            case gen_tcp:recv(Sock, 0) of
                {ok, B} ->
                    io:format("~p: ~p\n", [ParN, B]),
                    do_recv(Sock, [B | BPrev], ParN - 1);
                {error, closed} ->
                    {ok, BPrev}
            end
    end.
%%%%%%%%%%%%%%%%%%%%%%%%  END TCP SERVER  %%%%%%%%%%%%%%%%%%%%%%%%%%%


s() ->
        register(tcpserv,  spawn(?MODULE, tcp_server,    [])).
