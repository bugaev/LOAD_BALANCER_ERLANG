-module(tcp_client).
-export([client/0, start_client/0]).

client() ->
    io:format("Sending Cookie: ~s", [bvvfile:get_cookie()]),
    SomeHostInNet = "localhost", % to make it runnable on one machine
    {ok, Sock} = gen_tcp:connect(SomeHostInNet, 5678, [list, {packet, 0}]),
    ok = gen_tcp:send(Sock, [bvvfile:get_cookie(), "Trying to make a long long long long line."]),
    ok = gen_tcp:close(Sock).

start_client() ->
    spawn(tcp_client, client, []).
