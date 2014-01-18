%%%----------------------------------------------------------------------------
%%% @doc Erlang DNS (EDNS) server
%%% @author Hans Christian v. Stockhausen <hc@vst.io>
%%% @end
%%%----------------------------------------------------------------------------

-module(ed_udp_server).

-behaviour(gen_server).

%% API
-export([start_link/0, start_link/1, stop/0]).

%% behaviour callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
  terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(NUM_HANDLERS, 100).

-record(state, {socket, handlers=[]}).

%%%============================================================================
%%% API
%%%============================================================================


%%-----------------------------------------------------------------------------
%% @doc Start the server
%% @spec start_link(UdpPort::integer()) -> {ok, Pid::pid()}
%% @end
%%-----------------------------------------------------------------------------
start_link(UdpPort) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [UdpPort], []).

%% @doc Start the server on default port
%% @spec start_link() -> {ok, Pid::pid()}
%% @end
start_link() ->
  {ok, Port} = application:get_env(edns, port),
  start_link(Port).

%%-----------------------------------------------------------------------------
%% @doc Stop the server
%% @spec stop() -> ok
%% @end
%%-----------------------------------------------------------------------------
stop() ->
  gen_server:cast(?SERVER, stop).


%%%============================================================================
%%% behaviour callbacks
%%%============================================================================


init([UdpPort]) ->
  {ok, Socket} = gen_udp:open(UdpPort, [{active, false}, binary]),
  {ok, #state{socket=Socket}, 100}.

handle_call(_Request, _From, State) ->
  {noreply, State}.

handle_cast(stop, State) ->
  {stop, normal, State}.

handle_info(timeout, #state{socket=Socket}=State) ->
   error_logger:info_msg("T I M E O U T"),
   %ed_udp_pool_sup:start_child(),
   C = fun(_X) -> 
        {ok, C} = ed_udp_pool_sup:start_child(),
        C
      end,
   [H1|Hs] = Handlers = [C(X) || X <- lists:seq(1, ?NUM_HANDLERS, 1)],
   io:format("H1 is ~p", [H1]),
   gen_udp:controlling_process(Socket, H1),
   gen_server:call(H1, {take_socket, Socket, Hs++[H1]}),
   {noreply, State}.

terminate(_Reason, #state{socket=Socket}) ->
  gen_udp:close(Socket),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
