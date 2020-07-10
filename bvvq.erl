-module(bvvq).
-export[cmd_queue/0, s/0, send_message/1, start_client/1,
tcp_server/0, run/2, create_worker/1, get_worker_uptime/1, create_pool/0, create_bvv_pool/0, get_pool_uptimes/0, get_cpu_nums/0, time_subtract/2, get_submit_times_fake/0, print_uptimes/1, get_free_hosts/0, print_all_uptimes/0, get_best_free_host/0, node_feeder/3, time_server/3, my_cpu_util/0, my_avg1/0, kill_port/1, common_list_indices/1].


%Use this in get_pool_uptimes.
%-record(nodestat, {usage, load}).

-define(MinFreeCores, 1.00).
%-define(MinFreeCores, 60.0).
-define(TZeroAppx, 10000). %milliseconds.
-define(TInfAppx, 20000). %milliseconds.
-define(TCpuUtil, 500). %milliseconds.

-record(runpars, {njobs, time, request_time, queue, host, cmd, dir, outputfilename, erroutfilename}).

kill_port(NJob) ->
    PId = rpc:server_call(node(), timeserv, time_server_get_pid_reply, {get_pid, NJob}),
    if
        is_pid(PId) ->
            PId ! {terminate};
        PId == unknown ->
            io:format("Job unknown: ~p\n", [NJob]);
        PId == done ->
            io:format("Job done: ~p\n", [NJob]);
        true ->
            io:format("We shouldn't be here!; PId: ~p\n", [PId])
    end.

dict_safe_fetch(Key, Dict, Default) ->
    KeyExist = dict:is_key(Key, Dict),
    case KeyExist of
        true ->
            dict:fetch(Key, Dict);
        false ->
            Default
    end.

get_pool_names() ->
    [jupiter, galileo, io, cassini, europa, callisto, ganymede, monolith, marduk, megadon, jovian, oldjovian].

get_pool_speeds() ->
    dict:from_list([{oldjovian, 1.00}, {jovian, 1.52}, {europa, 1.19}, {callisto, 1.18}, {ganymede, 1.18}, {jupiter, 1.21}, {io, 1.20}, {galileo, 0.97}, {megadon, 2.93}, {cassini, 1.19}, {monolith, 1.70}, {marduk, 1.69}]).

get_cpu_nums() ->
    dict:from_list([{jupiter, 4}, {oldjovian, 4}, {galileo, 32}, {io, 16}, {cassini, 16}, {europa, 8}, {callisto, 8}, {ganymede, 8}, {megadon, 16}, {monolith, 48}, {marduk, 48}, {jovian, 64}]).

host_from_worker() ->
    lists:foldl(fun(HostName, Acc) -> dict:store(worker_name_from_host(HostName), HostName, Acc) end, dict:new(), get_pool_names()).

create_bvv_pool() ->
    PoolNames = get_pool_names(),
    lists:map(fun create_worker/1, PoolNames). 

create_pool() ->
    Dir = "/faculty/bugaev/PROGS/ERLANG",
    Arg = " -pa " ++ Dir,
    pool:start(worker, Arg),
%   rpc:multicall(pool:get_nodes(), net_kernel, set_net_ticktime, [1800]),
    rpc:multicall(pool:get_nodes(), application, start, [sasl]),
    rpc:multicall(pool:get_nodes(), application, start, [os_mon]).

print_uptimes(Uptimes) ->
    case Uptimes of
        {empty, {wait, X}} ->
            io:format("List is empty, next update: ~10.1f sec\n", [X / 1000.0]);
        _ ->
            ExplainedUptimesWithLimit = Uptimes,
            FreeCores = lists:foldl(
                fun({Name, NJobs, CpuUtil, Free, Efficiency}, Acc) ->
                    io:format("~10s:~20w~20.1f~20.1f~20.1f\n", [Name, NJobs, CpuUtil, Free, Efficiency]),
                    {NJobsBefore, RawCores, EffectiveCores} = Acc,
                    {NJobsBefore + NJobs, RawCores + Free, EffectiveCores + Free / Efficiency}
                end,
                {0, 0.0, 0.0}, ExplainedUptimesWithLimit),
                io:format("~10s:~20w~40.1f~20.1f\n", ["Total", element(1, FreeCores), element(2, FreeCores), element(3, FreeCores)])
                %io:format("~20.1f\t~20.1f\n", [1.0, 2.0]).
    end.


print_all_uptimes() ->
    io:format("All Hosts:\n"),
    print_uptimes(get_pool_uptimes()),
    io:format("\nHosts With *Free* CPU Cores:\n"),
    print_uptimes(get_free_hosts()).

get_best_free_host() ->
    case get_free_hosts() of
        {empty, {wait, X}} ->
            {empty, {wait, X}};
        [{HostName, NJobs, CpuUtil, FreeCores, _Speed} | _] ->
            CpuNums = get_cpu_nums(),
            CpuNum = dict:fetch(HostName, CpuNums),
            FreeCpuUtilCores = (1 - CpuUtil / 100.0) * CpuNum,
            {HostName, lists:min([FreeCores, FreeCpuUtilCores, CpuNum - NJobs])}
    end.

my_cpu_util() ->
    cpu_sup:util(),
    timer:sleep(?TCpuUtil),
    CpuUtil = cpu_sup:util(),
    Host = dict:fetch(node(), host_from_worker()), 
    case CpuUtil of
        {error, _} ->
            {Host, 100.0};
        _ ->
            {Host, CpuUtil}
    end.

my_avg1() ->
    Avg1 = cpu_sup:avg1(),
    Host = dict:fetch(node(), host_from_worker()), 
    CpuNums = get_cpu_nums(),
    case Avg1 of
        {error, _} ->
            {Host, dict:fetch(Host, CpuNums) * 256.0};
        _ ->
            {Host, Avg1}
    end.

common_list_indices(ListOfLists) ->
    %% This function works perfectly, but I didn't have to use it so far.
    sets:to_list(
      sets:intersection(
        lists:map(
          fun(Q) ->
                  sets:from_list(
                    lists:map(
                      fun({Host, _}) ->
                              Host
                      end,
                      Q)
                   )
          end,
          ListOfLists))).


get_pool_uptimes() ->
    Workers = lists:subtract(pool:get_nodes(), [node()]),

    {RawUptimes, _} = rpc:multicall(Workers, ?MODULE, my_avg1, [], infinity),
    NormUptimes = lists:map(fun({Host, X}) -> {Host, X / 256.0} end, RawUptimes),
    NormUptimesDict = dict:from_list(NormUptimes),

    {CpuUtils, _} = rpc:multicall(Workers, ?MODULE, my_cpu_util, [], infinity),
    CpuUtilsDict = dict:from_list(CpuUtils),

    NodeStat =
        dict:merge(
          fun(_, Upt, Cpu) -> 
                  {Upt, Cpu}
          end,
          NormUptimesDict, CpuUtilsDict),

    CpuNums = get_cpu_nums(),
    Speeds = get_pool_speeds(),
    NQueueJobs = rpc:server_call(node(), timeserv, time_server_get_njobs_reply, get_njobs),
    ExplainedUptimesWithLimit =
        lists:foldl(
          fun
              ({Name, {Upt, Cpu}}, Acc) ->
                           CpuNum = dict:fetch(Name, CpuNums),
                           Speed = dict:fetch(Name, Speeds),
                           NJobs = dict_safe_fetch(Name, NQueueJobs, 0),
                           [{Name, NJobs, Cpu, CpuNum - Upt, Speed} | Acc];
              (_, Acc) ->
                           Acc
          end,
          [], dict:to_list(NodeStat)),
    lists:keysort(4, ExplainedUptimesWithLimit). % Highest free cores at the bottom.

get_free_hosts() ->
    CpuNums = get_cpu_nums(),
    SubmitTimes = rpc:server_call(node(), timeserv, time_server_get_time_reply, get_time),
    Uptimes = get_pool_uptimes(),
    FreeHosts = lists:filter(
        fun({Host, NJobs, CpuUtil, FreeCores, _}) ->
            SubmitTime = dict_safe_fetch(Host, SubmitTimes, {0, 0, 0}),
            (FreeCores > ?MinFreeCores) and
            (timer:now_diff(now(), SubmitTime) / 1000.0 > ?TInfAppx) and
            ((1.0 - CpuUtil / 100.0) * dict:fetch(Host, CpuNums) > ?MinFreeCores) and
            (NJobs < dict:fetch(Host, CpuNums))
        end,
        Uptimes),
    case FreeHosts of
        [_ | _] ->
            FreeHosts;
        [] ->
            ShortestTimeToAppxInfty = 
            lists:min(
                lists:map(
                    fun({Host,_,_,_,_}) ->
                        SubmitTime = dict_safe_fetch(Host, SubmitTimes, {0, 0, 0}),
                        ?TInfAppx - timer:now_diff(now(), SubmitTime) / 1000.0
                    end,
                    Uptimes)),

            WaitTime =
            if
                ShortestTimeToAppxInfty < 0 ->
                    ?TInfAppx;
                true ->
                    ShortestTimeToAppxInfty
            end,
            {empty, {wait, trunc(WaitTime)}}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%  TCP SERVER  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
tcp_server() ->
    Prefix = bvvfile:get_cookie(),
    link(whereis(bvvq)),
    {ok, LSock} = gen_tcp:listen(5679, [list, {packet, 4}, {active,
                false}, {backlog, 999}]),
    NJobs = 1,
    tcp_server_loop(Prefix, LSock, NJobs).

tcp_server_loop(Prefix, LSock, NJobs) ->
    {ok, Sock} = gen_tcp:accept(LSock),
    {ok, Msg} = do_recv(Sock, [], 5),
    %io:format("(tcp_serv) Msg:~p\n", [Msg]),
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
            NJobsUpdated = NJobs + 1,
            RunPars =
            #runpars
            {
                njobs = NJobs,
                request_time = now(),
                cmd = lists:nth(1, MsgContent),
                dir = lists:nth(2, MsgContent),
                queue = lists:nth(3, MsgContent),
                outputfilename = lists:nth(4, MsgContent),
                erroutfilename = lists:nth(5, MsgContent)
            },
            bvvq ! {RunPars}
    end,
    tcp_server_loop(Prefix, LSock, NJobsUpdated).

do_recv(Sock, BPrev, ParN) ->
    case ParN of
        0 ->
            {ok, BPrev};
        _ ->
            case gen_tcp:recv(Sock, 0) of
                {ok, B} ->
                    do_recv(Sock, [B | BPrev], ParN - 1);
                {error, closed} ->
                    {ok, BPrev}
            end
    end.
%%%%%%%%%%%%%%%%%%%%%%%%  END TCP SERVER  %%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%  COMMAND QUEUE  (cmd_queue*) %%%%%%%%%%%%%
cmd_queue() ->
    io:format("cmd_queue service started:)~n"),
    %cmd_queue_loop(queue:new()).
    cmd_queue_loop(dict:new()).

cmd_queue_loop(Queues) ->
    receive
        %{stop} ->
        %    io:format("cmd_queue service finished.~n"),
        %    io:format("The queue: ~p~n", [MyQueue]),
        %    exit(stop);

        {From, Host} ->
            {QueueName, Queue} = rnd:get_random_dict_entry(Queues),
            io:format("QueueName: ~p\n", [QueueName]),
            case queue:out(Queue) of
                {{value, RunPars0}, UpdatedQueue} ->
                    RunPars = RunPars0#runpars{time = now(), host = Host},
                    io:format(
                        "Submitting command -->~p<--, "
                        "queue -->~p<--, working directory -->~p<--, to node ~p, "
                        "output -->~p<--, errout -->~p<--~n",
                        [RunPars#runpars.cmd,
                         RunPars#runpars.queue,
                         RunPars#runpars.dir,
                         RunPars#runpars.host,
                         RunPars#runpars.outputfilename,
                         RunPars#runpars.erroutfilename]),
                    PId = spawn(worker_name_from_host(Host), ?MODULE, run, [RunPars, node()]),
                    ok = rpc:server_call(node(), timeserv, time_server_set_time_reply, {set_time, RunPars, PId}),
                    %JobsLeft = queue:len(UpdatedQueue),
                    UpdatedQueueLen = queue:len(UpdatedQueue),
                    if 
                        UpdatedQueueLen > 0 ->
                            UpdatedQueues = dict:store(RunPars#runpars.queue, UpdatedQueue, Queues);
                        true ->
                            UpdatedQueues = dict:erase(RunPars#runpars.queue, Queues)
                    end,
                    JobsLeft =
                    dict:fold(
                        fun(_QueueName, QueueVal, JobsLeftSoFar) ->
                            queue:len(QueueVal) + JobsLeftSoFar
                        end,
                        0,
                        UpdatedQueues),
                    From ! {cmd_queue_reply, node(), JobsLeft};

                {empty, _UpdatedQueue} ->
                    UpdatedQueues = Queues,
                    io:format("ERROR: Queue is empty. We should not be here!!!~n", [])
            end,
            %io:format("UpdatedQueues: ~p~n", [dict:to_list(UpdatedQueues)]),
            cmd_queue_loop(UpdatedQueues);

        {Message} ->
            %io:format("Queues: ~p\n", [dict:to_list(Queues)]),
            JobsLeft =
            dict:fold(
                fun(_QueueName, Queue, JobsLeftSoFar) ->
                    queue:len(Queue) + JobsLeftSoFar
                end,
                0,
                Queues),
            io:format("JobsLeft:~p\n", [JobsLeft]),
            if
                JobsLeft < 1 ->
                    nodefeeder ! {queue_filled};
                true ->
                    wasnt_empty
            end,
            Queue = dict_safe_fetch(Message#runpars.queue, Queues, queue:new()),
            UpdatedQueue = queue:in(Message, Queue),
            UpdatedQueues = dict:store(Message#runpars.queue, UpdatedQueue, Queues),
            cmd_queue_loop(UpdatedQueues)
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%  END COMMAND QUEUE  (cmd_queue*) %%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%  NODE FEEDER  %%%%%%%%%%%%%%%%%%%%%%%%%%%%
node_feeder(IsQueueEmpty, LastSubmitParams, NewNodeFound) ->
    %io:format("Entering node_feeder: -->~p<-- -->~p<-- -->~p<--\n", [IsQueueEmpty, LastSubmitParams, NewNodeFound]),
    if
        IsQueueEmpty ->
            receive
                {queue_filled} ->
                    IsQueueEmptyUpdated = false,
                    node_feeder(IsQueueEmptyUpdated, LastSubmitParams, false)
            end;
        not IsQueueEmpty ->
            {LastHost, LastFreeCores} = LastSubmitParams,
            T = now(),
            TLast = T, % Needs changing!
            TDiff = timer:now_diff(T, TLast) * 1000000,
            if
                % If we can continue with the same node as before:
                ((LastFreeCores > ?MinFreeCores) and ((TDiff < ?TZeroAppx) or NewNodeFound)) ->
                    NewNodeFoundUpdated = false,
                    % Send a message to cmd_queue_loop and get a response synchronously:
                    %io:format("node_feeder: sending ~p\n", [LastHost]),
                    JobsLeft = rpc:server_call(node(), bvvq, cmd_queue_reply, LastHost),
                    %io:format("(Recieved in node_feeder): JobsLeft: ~p\n", [JobsLeft]),
                    if
                        JobsLeft < 1 ->
                            IsQueueEmptyUpdated = true;
                        true ->
                            IsQueueEmptyUpdated = false
                    end,
                    node_feeder(IsQueueEmptyUpdated, {LastHost, LastFreeCores - 1}, NewNodeFoundUpdated);
                    
                % If we can NOT continue with the same node as before:
                true ->
                    case get_best_free_host() of
                        {empty, {wait, X}} ->
                            %io:format("(node_feeder) Sleeping interval: ~p\n", [X]),
                            timer:sleep(X),
                            node_feeder(IsQueueEmpty, LastSubmitParams, NewNodeFound);
                        {FreeHost, FreeCores} ->
                            NewNodeFoundUpdated = true,
                            node_feeder(IsQueueEmpty, {FreeHost, FreeCores}, NewNodeFoundUpdated)
                    end
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%  END NODE FEEDER  %%%%%%%%%%%%%%%%%%%%%%%%%

% Time Utils  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
time_subtract({MegaSec, Sec, MicroSec}, SubtractSeconds) ->
    Timestamp = MegaSec * 1000000 * 1000000 + (Sec - SubtractSeconds) * 1000000 + MicroSec,
    {MegaSec1, Sec1, MicroSec1} = {Timestamp div 1000000000000, Timestamp div 1000000 rem 1000000, Timestamp rem 1000000},
    {MegaSec1, Sec1, MicroSec1}.

get_submit_times_fake() ->
    Workers = lists:subtract(pool:get_nodes(), [node()]),
    HostFromWorker = host_from_worker(),
    Hosts = lists:map(fun(Worker) -> dict:fetch(Worker, HostFromWorker) end, Workers),
    SubmitTimes = dict:from_list(lists:foldl(fun(HostName, Acc) -> [{HostName, {0, 0, 0}} | Acc] end, [], Hosts)),
    SubmitTimes.


time_server(SubmitTimes, HostQueues, JobPIds) ->
    receive
        {job_finished, Host, NJob} ->
            HostQueuesUpdated =
            dict:update(
                Host,
                fun(ListToBeUpdated) ->
                    lists:keydelete(NJob, #runpars.njobs, ListToBeUpdated)
                end,
                HostQueues),
            JobPIdsUpdated = lists:keyreplace(NJob, 1, JobPIds, {NJob, done}),
            time_server(SubmitTimes, HostQueuesUpdated, JobPIdsUpdated);

        {From, {get_pid, NJob}} ->
            Found = lists:keyfind(NJob, 1, JobPIds),
            Reply = 
            case Found of
                {_, Status} -> Status;
                _ -> unknown
            end, 
            From ! {time_server_get_pid_reply, node(), Reply},
            time_server(SubmitTimes, HostQueues, JobPIds);
        {From, get_time} ->
            From ! {time_server_get_time_reply, node(), SubmitTimes},
            time_server(SubmitTimes, HostQueues, JobPIds);
        {From, get_njobs} ->
            From ! {time_server_get_njobs_reply, node(), dict:map(fun(_Key, Val) -> length(Val) end, HostQueues)},
            time_server(SubmitTimes, HostQueues, JobPIds);
        {From, {set_time, RunPars, PId}} ->
            JobPIdsUpdated = [{RunPars#runpars.njobs, PId} | JobPIds],
            %io:format("JobPIdsUpdated: ~p\n", [JobPIdsUpdated]),
            HostQueuesUpdated = dict:append(RunPars#runpars.host, RunPars, HostQueues),
            %io:format("HostQueuesUpdated: ~p\n", [HostQueuesUpdated]),
            SubmitTimesUpdated = dict:store(RunPars#runpars.host, RunPars#runpars.time, SubmitTimes),
            From ! {time_server_set_time_reply, node(), ok},
            time_server(SubmitTimesUpdated, HostQueuesUpdated, JobPIdsUpdated)
    end,
    ok.
% END Time Utils  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%  Run System Command %%%%%%%%%%%%%%%%%%%%%
%run({NJob, _Time, Host, Cmd, Dir, OutputFileName, ErrOutFileName}, MasterNode) ->
run(RunPars, MasterNode) ->
    Port = erlang:open_port({spawn, RunPars#runpars.cmd}, [{cd, RunPars#runpars.dir}, exit_status , stderr_to_stdout]),
    io:format("Port: ~p\n", [Port]),
    loop(Port,[], RunPars),
    {timeserv, MasterNode} ! {job_finished, RunPars#runpars.host, RunPars#runpars.njobs},
    io:format("Job: ~p done.\n", [RunPars#runpars.njobs]).
        
loop(Port, Data, RunPars) ->
        receive
                {terminate} -> io:format("Got Terminate Request.\n", []),
                    %true = port_close(Port), % Doesn't do much.
                    OS_PId = element(2, erlang:port_info(Port, os_pid)),
                    io:format("Port os_pid: ~p\n", [OS_PId]),
                    %PGIDQuery = lists:flatten(io_lib:format("ps --no-heading -o \"%r\" ~p", [OS_PId])),
                    %PGID = os:cmd(PGIDQuery),
                    %KillCommand = lists:flatten(io_lib:format("kill -TERM -~s", [PGID])),
                    KillCommand = lists:flatten(io_lib:format("kill -TERM -~w", [OS_PId])),
                    io:format("Kill Command: ~p\n", [KillCommand]),
                    os:cmd(KillCommand),
                    loop(Port, Data, RunPars);

%               {Port, {data, NewData}} -> loop(Port, Data++NewData, RunPars);
                {Port, {data, NewData}} -> loop(Port, [NewData|Data], RunPars);
                {Port, {exit_status, 0}} ->
%                   OutData = lists:flatten(io_lib:format("Subject: Job ~p: <~s> ~s\n\n~72c\nJob Output:\n~72c\n~s", [RunPars#runpars.njobs, RunPars#runpars.cmd, "Done", $-, $-, Data])),
                    OutData = lists:flatten(io_lib:format("Subject: Job ~p: <~s> ~s\n\n~72c\nJob Output:\n~72c\n~s", [RunPars#runpars.njobs, RunPars#runpars.cmd, "Done", $-, $-, lists:reverse(Data)])),
                    file:write_file(RunPars#runpars.outputfilename, OutData);
                {Port, {exit_status, S}} ->
%                   OutData = lists:flatten(io_lib:format("Subject: Job ~p: <~s> ~s ~p\n\n~72c\nJob Output:\n~72c\n~s", [RunPars#runpars.njobs, RunPars#runpars.cmd, "Exit", S, $-, $-, Data])),
                    OutData = lists:flatten(io_lib:format("Subject: Job ~p: <~s> ~s ~p\n\n~72c\nJob Output:\n~72c\n~s", [RunPars#runpars.njobs, RunPars#runpars.cmd, "Exit", S, $-, $-, lists:reverse(Data)])),
                    file:write_file(RunPars#runpars.outputfilename, OutData),
%                   ErrData = lists:flatten(io_lib:format("Queue: Job finished with error code: ~p!\n\n~72c\nProgram Error Output:\n~72c\n~s\n", [S, $-, $-, Data])), 
                    ErrData = lists:flatten(io_lib:format("Queue: Job finished with error code: ~p!\n\n~72c\nProgram Error Output:\n~72c\n~s\n", [S, $-, $-, lists:reverse(Data)])), 
                    file:write_file(RunPars#runpars.erroutfilename, ErrData)
        end.
%%%%%%%%%%%%% END Run System Command %%%%%%%%%%%%%%%%%%%%%

create_worker(HostShort) ->
    Host = atom_to_list(HostShort) ++ ".local",
    {ok, WorkerNode} = slave:start(Host, worker),
    rpc:call(WorkerNode, application, start, [sasl]),
    rpc:call(WorkerNode, application, start, [os_mon]).

worker_name_from_host(HostShort) ->
    list_to_atom("worker@" ++ erlang:atom_to_list(HostShort) ++ ".local").

get_worker_uptime(HostShort) ->
    WorkerNode = worker_name_from_host(HostShort),
    rpc:call(WorkerNode, cpu_sup, avg1, []) / 256.

send_message(ServerNode) ->
    {bvvq, ServerNode} ! {"Hello World"}.


s() ->

        register(bvvq,     spawn(?MODULE, cmd_queue, [])),
        register(tcpserv,  spawn(?MODULE, tcp_server,    [])),
        register(nodefeeder,  spawn(?MODULE, node_feeder, [true, {none, -1.0}, false])),
        register(timeserv, spawn(?MODULE, time_server, [dict:new(), dict:new(), []])),
        create_pool(). 


start_client(ServerNode) ->
    spawn(?MODULE, send_message, [ServerNode]).

%rpc:multicall( [worker@jupiter.local, worker@galileo.local, worker@io.local, worker@cassini.local, worker@europa.local, worker@callisto.local, worker@ganymede.local, worker@monolith.local, worker@megadon.local, worker@jovian.local, worker@marduk.local], cpu_sup, avg1, []).
