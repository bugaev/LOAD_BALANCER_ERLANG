-module(tcp_server).
-export([server/0, start_server/0]).

server() ->
    Prefix = bvvfile:get_cookie(),
    {ok, LSock} = gen_tcp:listen(5678, [list, {packet, 0}, {active, false}]),
    {ok, Sock} = gen_tcp:accept(LSock),
    {ok, Msg} = do_recv(Sock, []),
    ok = gen_tcp:close(Sock),
    
    SecretPhraseFound = lists:prefix(Prefix, Msg),
    if SecretPhraseFound ->
            io:format("Message is authentic.~n", []);
        true ->
            io:format("Message is NOT authentic!!!~n", [])
    end,
    MsgContent = lists:nthtail(length(Prefix), Msg),
    io:format("Got this:~p~n", [MsgContent]).



do_recv(Sock, BPrev) ->
    case gen_tcp:recv(Sock, 0) of
        {ok, B} ->
            do_recv(Sock, B);
        {error, closed} ->
            {ok, BPrev}
    end.

start_server() ->
    spawn(tcp_server, server, []).
    %register(server, spawn(tcp_server, server, [])).
