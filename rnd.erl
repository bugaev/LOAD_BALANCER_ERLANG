-module(rnd).
-export[test/0, get_random_tuple/1, get_random_dict_entry/1].

%get_queues() ->
%    dict:from_list([{proj1, [1, 2, 3]}, {proj2, [4, 5, 6]}, {proj3, [7, 8, 9]}]).

get_weights() ->
    dict:from_list([{proj1, 1}, {proj2, 2.0}, {proj3, 1.0}]).

get_random_tuple_integrated_weights(KeyPos, List) ->
    X = random:uniform(),
    get_random_tuple_integrated_weights(X, KeyPos, List).

get_random_tuple_integrated_weights(_X, _KeyPos, [Head | []]) ->
    Head;

get_random_tuple_integrated_weights(X, KeyPos, [Head | Tail]) ->
    if
        element(KeyPos, Head) >= X ->
            Head;
        true ->
            get_random_tuple_integrated_weights(X, KeyPos, Tail)
    end.



get_weights_integrated(Weights) ->
    WSum =
    dict:fold(
        fun(_Key, Val, Acc) -> Acc + Val end,
        0.0,
        Weights),
    WeightsNormalized =
    dict:map(
        fun(_Key, Val) -> Val / WSum end,
        Weights),
    {WeightsIntegratedReverse, _} =
    dict:fold(
        fun(Key, Val, {List, WSumPrev}) -> WSumUpdated = Val + WSumPrev, {[{Key, WSumUpdated} | List], WSumUpdated} end,
        %fun(Key, Val, {List, WSum0}) -> {[{Key, WSum0 + Val} | List], WSum0 + Val} end,
        {[], 0.0},
        WeightsNormalized),
    WeightsIntegrated = lists:reverse(WeightsIntegratedReverse),
    %io:format("WSum: ~p, WeightsIntegrated: ~p\n", [WSum, WeightsIntegrated]),
    WeightsIntegrated.

get_random_tuple(Weights) ->
    get_random_tuple_integrated_weights(2, get_weights_integrated(Weights)).

get_random_dict_entry(Dict) ->
    EqualWeightsDict =
    dict:map(
        fun(_Key, _Val) -> 1.0 end,
        Dict),
    {Key, _} = get_random_tuple(EqualWeightsDict),
    {Key, dict:fetch(Key, Dict)}.

test() ->
    get_random_tuple(get_weights()).
