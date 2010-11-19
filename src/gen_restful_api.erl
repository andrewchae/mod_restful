%%%----------------------------------------------------------------------
%%% File    : gen_restful_api.erl
%%% Author  : Jonas Ådahl <jadahl@gmail.com>
%%% Purpose : Behaviour for mod_restful API modules
%%% Created : 11 Nov 2010 by Jonas Ådahl <jadahl@gmail.com>
%%%
%%%
%%% Copyright (C) 2010   Jonas Ådahl
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(gen_restful_api).
-author('jadahl@gmail.com').

-export(
    [
        % behaviour
        behaviour_info/1,

        % utilities
        authenticate_admin_request/1,
        authorize_key_request/1,
        opts/2
    ]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-include("include/mod_restful.hrl").

%
% Behaviour
%

behaviour_info(callbacks) ->
    [
        {process, 1}
    ].

%
% Utilities
%

authenticate_admin_request(#rest_req{
        host = ReqHost,
        http_request = HTTPRequest}) ->
    case HTTPRequest#request.auth of
        {HTTPUser, Password} ->
            case jlib:string_to_jid(HTTPUser) of
                #jid{user = User, server = Host} = JID when (User /= []) and (Host /= []) ->
                    case ejabberd_auth:check_password(User, Host, Password) of
                        true ->
                            acl:match_rule(ReqHost, configure, JID);
                        _ ->
                            deny
                    end;
                _ ->
                    deny
            end;
        _ ->
            deny
    end.

authorize_key(Key, Opts) ->
    ConfiguredKey = opts(key, Opts),
    case {list_to_binary(ConfiguredKey), Key} of
        {undefined, _} ->
            {error, no_key_configured};
        {Key, Key} when is_binary(Key) orelse is_list(Key) ->
            allow;
        _E ->
            deny
    end.

-spec authorize_key_request(#rest_req{}) -> allow | deny.
authorize_key_request(#rest_req{
        http_request = #request{
            method = 'GET',
            q = Q},
        options = Opts}) ->
    Key = opts("key", Q),
    authorize_key(Key, Opts);
authorize_key_request(#rest_req{
        http_request = #request{method = 'POST'},
        format = Format,
        options = Opts} = Req) ->
    case Format of
        undefined ->
            deny;
        Format ->
            Key = get_key(Format, Req),
            authorize_key(Key, Opts)
    end.

get_key(json, #rest_req{data = Data}) ->
    case Data of
        {struct, Struct} ->
            case lists:keysearch(<<"key">>, 1, Struct) of
                {value, {_, Key}} ->
                    Key;
                _ ->
                    undefined
            end;
        _ ->
            undefined
    end.

opts(Key, Opts) ->
    case lists:keysearch(Key, 1, Opts) of
        {value, {_, Value}} ->
            Value;
        _ ->
            undefined
    end.
