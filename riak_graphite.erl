%% -------------------------------------------------------------------
%%
%% riak_graphite: Server process to emit statistics to Graphite
%%
%% Copyright (c) 2013 Basho Technologies, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License. You may obtain
%% a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied. See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(riak_graphite).
-compile(export_all).
-behaviour(gen_server).
 
-export([start/2, start/3, start/4, start/5, start/6, stop/0, is_enabled/0, enable/0, disable/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
terminate/2, code_change/3]).
 
-record(state, {socket, host, port, interval, prefix, node, filter}).
 
-define(MAX_UDP_MESSAGE_SIZE, 512).
 
-define(DEFAULT_INTERVAL, 60).
-define(DEFAULT_PORT, 2003).
-define(DEFAULT_LOCAL_PORT, 20003).
-define(DEFAULT_STATSFILTER, [node_get_fsm_objsize_mean,
node_get_fsm_objsize_median,
node_get_fsm_objsize_95,
node_get_fsm_objsize_100,
node_get_fsm_time_mean,
node_get_fsm_time_median,
node_get_fsm_time_95,
node_get_fsm_time_100,
node_put_fsm_time_mean,
node_put_fsm_time_median,
node_put_fsm_time_95,
node_put_fsm_time_100,
node_get_fsm_siblings_mean,
node_get_fsm_siblings_median,
node_get_fsm_siblings_95,
node_get_fsm_siblings_100,
memory_processes_used,
read_repairs,
read_repairs_total,
sys_process_count,
coord_redirs_total,
pbc_connect,
pbc_active,
pipeline_active,
pipeline_create_one,
list_fsm_create,
list_fsm_active,
index_fsm_create,
index_fsm_active]).
 
%% @doc Check to see if server is enabled.
-spec is_enabled() -> boolean().
is_enabled() ->
case application:get_env(riak_graphite, enabled) of
{ok, true} ->
true;
_ ->
false
end.
 
%% @doc Enable RiakGraphite integration server.
-spec enable() -> ok | {error, term()}.
enable() ->
case application:get_env(riak_graphite, enabled) of
{ok, error} ->
{error, "riak_graphite encountered error during startup and can not be enabled"};
{ok, true} ->
ok;
{ok, false} ->
application:set_env(riak_graphite, enabled, true),
ok;
undefined ->
{error, "riak_graphite has not been started"}
end.
 
%% @doc Disable RiakGraphite integration server.
-spec disable() -> ok | {error, term()}.
disable() ->
case application:get_env(riak_graphite, enabled) of
{ok, error} ->
{error, "riak_graphite encountered error during startup and can not be disabled"};
{ok, false} ->
ok;
{ok, true} ->
application:set_env(riak_graphite, enabled, false),
ok;
undefined ->
{error, "riak_graphite has not been started"}
end.
 
%% @doc Start Riak Graphite integration server.
-spec start(string(), string()) -> {ok, pid()} | ignore | {error, term()}.
start(Prefix, Host) ->
start(Prefix, Host, ?DEFAULT_INTERVAL).
 
%% @doc Start Riak Graphite integration server.
-spec start(string(), string(), pos_integer()) -> {ok, pid()} | ignore | {error, term()}.
start(Prefix, Host, Interval) ->
start(Prefix, Host, Interval, ?DEFAULT_STATSFILTER).
 
%% @doc Start Riak Graphite integration server.
-spec start(string(), string(), pos_integer(), list()) -> {ok, pid()} | ignore | {error, term()}.
start(Prefix, Host, Interval, StatsFilterList) ->
start(Prefix, Host, Interval, StatsFilterList, ?DEFAULT_PORT).
 
%% @doc Start Riak Graphite integration server.
-spec start(string(), string(), pos_integer(), list(), pos_integer()) -> {ok, pid()} | ignore | {error, term()}.
start(Prefix, Host, Interval, StatsFilterList, Port) ->
start(Prefix, Host, Interval, StatsFilterList, Port, ?DEFAULT_LOCAL_PORT).
 
%% @doc Start Riak Graphite integration server.
-spec start(string(), string(), pos_integer(), list(), pos_integer(), pos_integer()) -> {ok, pid()} | ignore | {error, term()}.
start(Prefix, Host, Interval, StatsFilterList, Port, LocalPort) when is_list(Prefix)
andalso is_list(StatsFilterList)
andalso is_list(Host)
andalso is_integer(Interval) andalso Interval > 0
andalso is_integer(Port) andalso Port > 0
andalso is_integer(LocalPort) andalso LocalPort > 0 ->
gen_server:start({local, ?MODULE}, ?MODULE, [Prefix, Host, StatsFilterList, Interval, Port, LocalPort], []).
 
%% @doc Stop Riak Graphite integration server.
-spec stop() -> ok.
stop() ->
gen_server:cast(?MODULE, stop).
 
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State} |
%% {ok, State, Timeout} |
%% ignore |
%% {stop, Reason}
%% --------------------------------------------------------------------
init([Prefix, Host, StatsFilterList, Interval, Port, LocalPort]) ->
case inet:getaddr(Host, inet) of
{error, Reason} ->
ErrMsg = io_lib:fwrite("Error resolving host ~p : ~p", [Host, Reason]),
application:set_env(riak_graphite, enabled, error),
{stop, {error, ErrMsg}};
{ok, _} ->
case connect_to_port(LocalPort) of
{error, Error} ->
application:set_env(riak_graphite, enabled, error),
{stop, {error, Error}};
{ok, Socket} ->
erlang:send_after(1000 * Interval, self(), gather_stats),
Node = string:join(string:tokens(atom_to_list(node()), "\."), "-"),
application:set_env(riak_graphite, enabled, true),
{ok, #state{socket = Socket, host = Host, port = Port, interval = Interval, prefix = Prefix, node = Node, filter = StatsFilterList}}
end
end.
 
%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State} |
%% {reply, Reply, State, Timeout} |
%% {noreply, State} |
%% {noreply, State, Timeout} |
%% {stop, Reason, Reply, State} | (terminate/2 is called)
%% {stop, Reason, State} (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call(_Msg, _From, State) ->
{noreply, State}.
 
%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State} |
%% {noreply, State, Timeout} |
%% {stop, Reason, State} (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(stop, State) ->
{stop, "Process ordered to stop", State};
handle_cast(_Msg, State) ->
{noreply, State}.
 
%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State} |
%% {noreply, State, Timeout} |
%% {stop, Reason, State} (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(gather_stats, #state{interval = Interval, filter = Filter} = State) ->
case application:get_env(riak_graphite, enabled) of
{ok, true} ->
StatList = [{S, V} || {S, V} <- riak_kv_stat:get_stats(), is_integer(V) andalso lists:member(S, Filter)],
send_stats_to_graphite(State, StatList),
erlang:send_after(1000 * Interval, self(), gather_stats);
_ ->
erlang:send_after(1000 * Interval, self(), gather_stats)
end,
{noreply, State};
handle_info(_Info, State) ->
{noreply, State}.
 
%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
ok.
 
%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
{ok, State}.
 
%% hidden
connect_to_port(LocalPort) ->
connect_to_port(LocalPort, 10).
 
connect_to_port(_, 0) ->
EMsg = io_lib:fwrite("Unable to bind to local UDP port.", []),
{error, EMsg};
connect_to_port(LocalPort, Attempts) ->
case gen_udp:open(LocalPort, [binary]) of
{error, _} ->
connect_to_port((LocalPort + 1), (Attempts - 1));
{ok, Socket} ->
inet:setopts(Socket, [{active, true}]),
{ok, Socket}
end.
 
send_stats_to_graphite(State, Stats) ->
send_stats_to_graphite(State, Stats, []).
 
send_stats_to_graphite(#state{host = Host, port = Port, socket = Socket}, [], Msg) ->
gen_udp:send(Socket, Host, Port, list_to_binary(Msg)),
ok;
send_stats_to_graphite(#state{prefix = Prefix, node = Node} = State, [{S, V} | Rest], []) ->
Msg = io_lib:fwrite("~s.~s.~s ~p", [Prefix, Node, atom_to_list(S), V]),
send_stats_to_graphite(State, Rest, Msg);
send_stats_to_graphite(#state{host = Host, port = Port, socket = Socket, prefix = Prefix, node = Node} = State, [{S, V} | Rest], Msg) ->
Message = io_lib:fwrite("~s.~s.~s ~p", [Prefix, Node, atom_to_list(S), V]),
case (length(Msg) + length(Message) + 1) > ?MAX_UDP_MESSAGE_SIZE of
true ->
gen_udp:send(Socket, Host, Port, list_to_binary(Msg)),
send_stats_to_graphite(State, Rest, Message);
false ->
Message2 = lists:flatten([Message | "\n"], Msg),
send_stats_to_graphite(State, Rest, Message2)
end.
