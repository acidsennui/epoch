%%%-------------------------------------------------------------------
%%% @copyright (C) 2018, Aeternity Anstalt
%%% @doc
%%% API functions for compiling and encoding Ring contracts.
%%% @end
%%%-------------------------------------------------------------------

-module(aect_evm).

-export([ call/2
	, encode_call_data/3
	, execute_call/2
        ]).



hexstring_encode(Code) ->
    CodeAsHexString = 
        << << (hex_nibble(X)):8, (hex_nibble(Y)):8 >>
           || <<X:4, Y:4>> <= Code >>,
    <<"0x", CodeAsHexString/binary >>.
    
hex_nibble(X) ->
    if X < 10 -> X+$0;
       true   -> X+87
    end.

-spec encode_call_data(binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
encode_call_data(Contract, Function, Argument) ->
    {ok, <<Function/binary, Argument/binary>>}.

-spec call(binary(), binary()) -> {ok, binary()} | {error, binary()}.
call(Code, CallData) ->
    Spec = #{ code => Code
            , address => 0
            , caller => 0
            , data => CallData
            , gas => 1000000
            , gasPrice => 1
            , origin => 0
            , value => 0
            , currentCoinbase => 1
            , currentDifficulty => 1
            , currentGasLimit => 1000000
            , currentNumber => 1
            , currentTimestamp => 1
            },
    try execute_call(Spec, false) of
        #{ out := Out } ->
            file:write_file("/home/happi/tmp/call_res.txt",
	        io_lib:format("~p~n", [hexstring_encode(Out)])),
            {ok, hexstring_encode(Out)};
        E ->
	file:write_file("/home/happi/tmp/out.txt", io_lib:format("~p~n", [E])),
	{error, list_to_binary(io_lib:format("~p", [E]))}
    catch T:E ->
	file:write_file("/home/happi/tmp/error_out.txt", io_lib:format("~p:~p~n", [T,E])),
	{error, list_to_binary(io_lib:format("~p", [E]))}
    end.


-spec execute_call(map(), boolean()) -> map() | {error, term()}.
execute_call(#{ code := CodeAsHexBinString
              , address := Address
              , caller := Caller
              , data := CallData
              , gas := Gas
              , gasPrice := GasPrice
              , origin := Origin
              , value := Value
              , currentCoinbase := CoinBase
              , currentDifficulty := Diffculty
              , currentGasLimit := GasLimit
              , currentNumber := Number
              , currentTimestamp := TS
              }, Trace) ->
    %% TODO: Handle Contract In State.
    Code = binint_to_bin(CodeAsHexBinString),
    Spec =
        #{ exec => #{ code => Code
                    , address => Address
                    , caller => Caller
                    , data => CallData
                    , gas => Gas
                    , gasPrice => GasPrice
                    , origin => Origin
                    , value => Value
                    },
           env => #{ currentCoinbase => CoinBase
                   , currentDifficulty => Diffculty
                   , currentGasLimit => GasLimit
                   , currentNumber => Number
                   , currentTimestamp => TS
                   },
           pre => #{}},
    TraceSpec =
        #{ trace_fun =>
               fun(S,A) -> io_lib:format(S,A) end
         , trace => Trace
         },
    State = aevm_eeevm_state:init(Spec, TraceSpec),
    Result = aevm_eeevm:eval(State),
    Result.

binint_to_bin(<<"0x", Bin/binary>>) ->
    << <<(hex_to_int(X)):4>> || <<X:8>> <= Bin>>;
binint_to_bin(<<"0", _/binary>> = Bin) ->
    %% Don't know what to do.
    %% Is this an attempt to pad?
    error({unexpected, Bin});
binint_to_bin(Bin) when is_binary(Bin) ->
    Int = binary_to_integer(Bin),
    binary:encode_unsigned(Int).

hex_to_int(X) when $A =< X, X =< $F -> 10 + X - $A;
hex_to_int(X) when $a =< X, X =< $f -> 10 + X - $a;
hex_to_int(X) when $0 =< X, X =< $9 -> X - $0.
