-module(tmessenger).
-compile(export_all).
% -export([register/0]).

server_node() ->
    'tmessenger@Harshs-MacBook-Air'.
server(User_List) ->
    receive
        {From, logon, Name} ->
            New_User_List = server_logon(From, Name, User_List),
            server(New_User_List);
        {From, logoff} ->
            New_User_List = server_logoff(From, User_List),
            server(New_User_List);
        {From, message_to, To, Message} ->
            server_transfer(From, To, Message, User_List),
            io:format("list is now: ~p~n", [User_List]),
            server(User_List);
        {From, follow_to, To} ->
            server_follow(From, To, User_List),
            server(User_List);
        %used to register a new user
        {register, From, Msg, Username, Password} ->
            Temp = #{Username => Password},

            Userdat = persistent_term:get(userdata),

            NewUserdat = maps:merge(Temp, Userdat),

            persistent_term:put(userdata, NewUserdat),

            UserList = persistent_term:get(userdata),
            io:fwrite("~p", [UserList])
    end,
    server(User_List).

%helper funtion that helps in fetching data from server.
datafetcher() ->
    receive
        {user_list, From} ->
            Userdat = persistent_term:get(userdata),
            From ! {Userdat}
    end,
    datafetcher().

%%% Start the server
start_server() ->
    Msg = "dfldkflldf",
    persistent_term:put(m, Msg),

    Userlist = [],
    persistent_term:put(userlist, Userlist),

    % username => password
    Userdata = #{},
    persistent_term:put(userdata, Userdata),

    % username => pid
    Usertopid = #{},
    persistent_term:put(usertopid, Usertopid),

    % pid => username
    Pidtouser = #{},
    persistent_term:put(pidtouser, Pidtouser),

    % username => {List of tweets}
    TweetsMap = #{},
    persistent_term:put(tweets, TweetsMap),

    % username => {list of users who are following username}
    FollowersMap = #{},
    persistent_term:put(followers, FollowersMap),

    % username => {list of users that username follows}
    FollowingMap = #{},
    persistent_term:put(following, FollowingMap),

    register(fetch, spawn(messenger, datafetcher, [])),
    register(messenger, spawn(messenger, server, [[]])).

%%% Server adds a new user to the user list
server_logon(From, Name, User_List) ->
    %% check if logged on anywhere else
    case lists:keymember(Name, 2, User_List) of
        true ->
            %reject logon
            From ! {messenger, stop, user_exists_at_other_node},
            User_List;
        false ->
            From ! {messenger, logged_on},
            %add user to the list
            [{From, Name} | User_List]
    end.

%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).

server_follow(From, To, User_List) ->
    %% check that the user is logged on and who he is
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {messenger, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_follow(From, Name, To, User_List)
    end.

server_follow(From, Name, To, User_List) ->
    %% Find the receiver and send the message
    case lists:keysearch(To, 2, User_List) of
        false ->
            From ! {messenger, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {follow_from, Name},
            From ! {messenger, sent}
    end.

%%% Server transfers a message between user
server_transfer(From, To, Message, User_List) ->
    %% check that the user is logged on and who he is
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {messenger, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transfer(From, Name, To, Message, User_List)
    end.

%%% If the user exists, send the message
server_transfer(From, Name, To, Message, User_List) ->
    %% Find the receiver and send the message
    case lists:keysearch(To, 2, User_List) of
        false ->
            From ! {messenger, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_from, Name, Message},
            From ! {messenger, sent}
    end.

%%% User Commands

reg(Username, Password) ->
    {messenger, server_node()} ! {register, self(), "df", Username, Password}.

logon(Name, Password) ->
    case whereis(mess_client) of
        undefined ->
            Followers = #{Name => []},
            persistent_term:put(followers, Followers),
            persistent_term:put(user, Name),
            Tweets = #{Name => []},
            persistent_term:put(tweets, Tweets),

            fetch ! {user_list, self()},

            receive
                {Dat} ->
                    Userdata = Dat,
                    io:fwrite("~p", [Dat])
            end,

            Booluser = maps:is_key(Name, Userdata),

            if
                Booluser == true ->
                    Pass = maps:get(Name, Userdata),

                    if
                        Password == Pass ->
                            register(
                                mess_client,
                                spawn(messenger, client, [server_node(), Name])
                            );
                        true ->
                            io:fwrite("hatt")
                    end;
                true ->
                    io:fwrite("df")
            end;
        _ ->
            already_logged_on
    end.

logoff() ->
    mess_client ! logoff.

follow(ToName) ->
    case whereis(mess_client) of
        undefined ->
            not_logged_on;
        _ ->
            mess_client ! {follow_to, ToName},
            ok
    end.

message(ToName, Message) ->
    % Test if the client is running
    case whereis(mess_client) of
        undefined ->
            not_logged_on;
        _ ->
            mess_client ! {message_to, ToName, Message},
            ok
    end.

tweet(Message) ->
    % Test if the client is running
    case whereis(mess_client) of
        undefined ->
            not_logged_on;
        _ ->
            FollowersMap = persistent_term:get(followers),
            User = persistent_term:get(user),
            List = maps:get(User, FollowersMap),

            TweetsMapA = persistent_term:get(tweets),
            TweetsA = maps:get(User, TweetsMapA),
            TweetsB = lists:append(TweetsA, [Message]),
            TweetsMapB = maps:update(User, TweetsB, TweetsMapA),
            persistent_term:put(tweets, TweetsMapB),
            io:fwrite("~p~n", [TweetsB]),

            lists:foreach(
                fun(Elem) ->
                    io:fwrite("Elem: ~p~n", [Elem]),
                    mess_client ! {message_to, Elem, Message}
                end,
                List
            )
    end.

search(Query) ->
    {fetch,server_node()} ! {}
    TweetsMap = persistent_term:get(tweets),
    User = persistent_term:get(user),
    Tweets = maps:get(User, TweetsMap),

    lists:foreach(
        fun(S) ->
            Bool = string:str(S, Query) > 0,
            if
                Bool == true ->
                    io:fwrite("Result: ~p~n", [S]);
                true ->
                    ok
            end
        end,
        Tweets
    ).

%%% The client process which runs on each server node
client(Server_Node, Name) ->
    {messenger, Server_Node} ! {self(), logon, Name},
    await_result(),
    client(Server_Node).

client(Server_Node) ->
    receive
        logoff ->
            {messenger, Server_Node} ! {self(), logoff},
            exit(normal);
        {message_to, ToName, Message} ->
            {messenger, Server_Node} ! {self(), message_to, ToName, Message},
            await_result();
        {message_from, FromName, Message} ->
            io:format("Message from ~p: ~p~n", [FromName, Message]),
            TweetsMap = persistent_term:get(tweets),
            User = persistent_term:get(user),
            Tweets = maps:get(User, TweetsMap),
            Tweets2 = lists:append(Tweets, [Message]),
            TweetsMap2 = maps:update(User, Tweets2, TweetsMap),
            persistent_term:put(tweets, TweetsMap2),
            io:fwrite("~p~n", [Tweets2]);
        {follow_to, ToName} ->
            {messenger, Server_Node} ! {self(), follow_to, ToName},
            await_result();
        {follow_from, FromName} ->
            FollowersMap = persistent_term:get(followers),
            User = persistent_term:get(user),
            List = maps:get(User, FollowersMap),
            List2 = lists:append(List, [FromName]),
            FollowersMap2 = maps:update(User, List2, FollowersMap),
            FollowersMap3 = maps:merge(FollowersMap, FollowersMap2),
            persistent_term:put(followers, FollowersMap3),

            receive
                {UserList} ->
                    io:fwrite("~p", [UserList])
            end,
            io:format("Follow from: ~p~n to : ~p~n", [FromName, User]),
            io:format("Followers: ~p~n", [FollowersMap3])
    end,
    client(Server_Node).

%%% wait for a response from the server
await_result() ->
    receive
        % Stop the client
        {messenger, stop, Why} ->
            io:format("~p~n", [Why]),
            exit(normal);
        % Normal response
        {messenger, What} ->
            io:format("~p~n", [What])
    end.