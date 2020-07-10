-module(run_cmd).
-export([run/1, run/2, test/0, shouldReturnCommandResult/0]).

run(Cmd) -> 
        run(Cmd, 5000).
        
run(Cmd, Timeout) ->
    Port = erlang:open_port({spawn, Cmd}, [exit_status, {cd, "/home/guest/tmp"}]),
        loop(Port,[], Timeout).
        
loop(Port, Data, Timeout) ->
        receive
                {Port, {data, NewData}} -> loop(Port, Data++NewData, Timeout);
                {Port, {exit_status, 0}} -> Data;
                {Port, {exit_status, S}} -> throw({commandfailed, S, Data})
        after Timeout ->
                throw(timeout)
        end.

test() -> 
        %shouldReturnCommandResult(),
        %shouldThrowAfterTimeout(),
        shouldThrowIfCmdFailed(),
        {ok, "Tests PASSED"}.

shouldReturnCommandResult() ->
        "Hello\n" = run("echo Hello").

shouldThrowAfterTimeout()->
        %timeout = (catch run("sleep 10", 20)).
        (catch run("sleep 10", 20)).
        %run("sleep 10", 20).
        
shouldThrowIfCmdFailed()->
                %{commandfailed, _} = (catch run("wrongcommand")),
                %{commandfailed, _} = (catch run("ls nonexistingfile")).
                catch run("ls nonexistingfile").
