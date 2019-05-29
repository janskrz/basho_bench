%% -------------------------------------------------------------------
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(basho_bench_driver_raft).

-export([new/1,
         run/4]).

-include("basho_bench.hrl").

%% ====================================================================
%% API
%% ====================================================================

-define(API_MODULE, raft_console).

new(Id) ->
    Nodes   = basho_bench_config:get(raft_client_nodes),

    %% Try to ping each of the nodes
    ping_each(Nodes, Id),

    %% Choose the node using our ID as a modulus
    TargetNode = hd(Nodes),
    %TargetNode = lists:nth((Id rem length(Nodes)+1), Nodes),
    ?INFO("Using target node ~p for worker ~p\n", [TargetNode, Id]),

    case rpc:call(TargetNode, ?API_MODULE, status, [[]]) of
        {badrpc, _Reason} ->
            ?FAIL_MSG("Failed to connect to ~p: ~p\n", [TargetNode, _Reason]);
        _ ->
            {ok, TargetNode}
    end.

run(get, _KeyGen, _ValueGen, State) ->
    case rpc:call(State, ?API_MODULE, read, []) of
        {ok, _Value} ->
            {ok, State};
        {fail, not_found} ->
            {ok, State}
    end;
run(put, _KeyGen, ValueGen, State) ->
    Payload = ValueGen(),
    case rpc:call(State, ?API_MODULE, inc, [Payload]) of
        ok ->
            {ok, State};
        Error ->
            {error, Error, State}
    end;
run(update, _KeyGen, _ValueGen, State) ->
    %% we do everything via get and put, even though puts are updates...
    {error, not_supported, State};
run(delete, _KeyGen, _ValueGen, State) ->
    {error, not_supported, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================

ping_each([], _Id) ->
    ok;
ping_each([Node | Rest], Id) ->
    case net_adm:ping(Node) of
        pong ->
            ping_each(Rest, Id);
        pang ->
            ?FAIL_MSG("Worker ~w failed to ping node ~p\n", [Id, Node])
    end.
