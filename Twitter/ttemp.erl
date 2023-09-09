-module(ttemp).
-compile(export_all).
% -export([register/0]).

server_node() ->
    'ttemp@Harshs-MacBook-Air'.
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
        {user_list, Pid} ->
            io:fwrite("~p", Pid);
        %used to register a new user
        {register, From, Msg, Username, Password} ->
            Temp = #{Username => Password},

            Userdat = persistent_term:get(userdata),

            NewUserdat = maps:merge(Temp, Userdat),

            persistent_term:put(userdata, NewUserdat),

            UserList = persistent_term:get(userdata),

            Temp_followers = #{Username => []},

            Followers = persistent_term:get(followers),

            NewFollowersmp = maps:merge(Followers, Temp_followers),

            persistent_term:put(followers, NewFollowersmp),

            Fol = persistent_term:get(followers),

            Temp_following = #{Username => []},

            Following = persistent_term:get(following),

            NewFollowingmp = maps:merge(Following, Temp_following),

            persistent_term:put(following, NewFollowingmp),

            Temp_tweet = #{Username => []},

            Tweetmp = persistent_term:get(tweets),

            NewTweetmp = maps:merge(Tweetmp, Temp_tweet),

            persistent_term:put(tweets, NewTweetmp),

            Temp_lsttweet = #{Username => ""},

            Lasttweetmp = persistent_term:get(lastmsg),

            NewLastTweetmp = maps:merge(Lasttweetmp, Temp_lsttweet),

            persistent_term:put(lastmsg, NewLastTweetmp),

            io:fwrite("~p", [NewLastTweetmp]);
        % io:fwrite("~p||~p",[UserList,Fol]);

        {update, Followmp} ->
            persistent_term:put(followers, Followmp);
        % io:fwrite("~p",[Followmp]);
        {tweetupd, Tweetmap, Alltweets} ->
            io:fwrite("~p", [Tweetmap]),
            persistent_term:put(alltweets, Alltweets),
            persistent_term:put(tweets, Tweetmap);
        {updlstmsg, Message, Name} ->
            Lastmsg = persistent_term:get(lastmsg),
            Lastmsg2 = maps:update(Name, Message, Lastmsg),
            persistent_term:put(lastmsg, Lastmsg2)
    end,
    server(User_List).

%helper funtion that helps in fetching data from server.
datafetcher() ->
    receive
        {user_list, From} ->
            Userdat = persistent_term:get(userdata),
            From ! {Userdat};
        {followmap, From} ->
            Followmp = persistent_term:get(followers),
            From ! {Followmp};
        {tweetmap, From} ->
            Tweetmp = persistent_term:get(tweets),
            Alltweets = persistent_term:get(alltweets),
            From ! {Tweetmp, Alltweets};
        {lstmsg, From} ->
            Lastmsg = persistent_term:get(lastmsg),
            From ! {Lastmsg}
    end,
    datafetcher().

for_reg(0) ->
    ok;
for_reg(N) ->
    reg(N, N),
    for_reg(N - 1).

for_log(0, Max) ->
    io:fwrite("\n"),
    ok;
for_log(N, Max) ->
    % io:fwrite("\nN: ~p~n", [N]),
    logonAuto(N, N, Max),
    for_log(N - 1, Max).

for_follow(0, Max) ->
    io:fwrite("\n"),
    ok;
for_follow(N, Max) ->
    User1 = rand:uniform(N),
    User2 = getRandom(User1, Max),
    persistent_term:put(user, User1),

    followAuto(User1, User2),
    tweetAuto(User2, "Hello"),

    for_follow(N - 1, Max).

for_off(0) ->
    ok;
for_off(N) ->
    logoffAuto(N, N),
    for_off(N - 1).

logoffAuto(N, N) ->
    {fetch, server_node()} ! {user_list, self()},

    receive
        {Dat} ->
            Userdata = Dat
    end,
    maps:remove(N, Userdata),
    io:fwrite("@~p has logged off\n", [N]),
    X = maps:size(Userdata),
    if
        X == 0 ->
            exit(bas);
        true ->
            ok
    end.

getRandom(User1, N) ->
    User2 = rand:uniform(N),
    if
        User1 == User2 ->
            getRandom(User1, N);
        true ->
            User2
    end.

tweetAuto(User, Message) ->
    FollowersMap = persistent_term:get(folAuto),
    % io:fwrite("FollowersMap: ~p~n", [FollowersMap]),
    % io:fwrite("List: ~p~n", [maps:get(User, FollowersMap)]),

    % mess_client ! {fetchmyname, self()},

    % receive
    %     {Myname} ->
    %         User = Myname
    % end,

    {fetch, server_node()} ! {tweetmap, self()},
    receive
        {Tweetmp, Alt} ->
            Tweet = Tweetmp,
            Alltweets = Alt
    end,

    Tweetsmap = persistent_term:get(tweetsAuto),

    % User = persistent_term:get(user),

    Newalltweets = lists:append(Alltweets, [Message]),

    List = maps:get(User, FollowersMap),

    Tweetlist = maps:get(User, Tweetsmap),

    Tweetlist2 = lists:append(Tweetlist, [Message]),

    Tweetmp1 = maps:update(User, Tweetlist2, Tweetsmap),
    % NewTweetmp = maps:merge(Tweetmp1, Tweetsmap),

    {messenger, server_node()} ! {tweetupd, Tweetmp1, Newalltweets},

    lists:foreach(
        fun(Elem) ->
            io:fwrite("To: @~p From: @~p Tweet: ~p~n", [Elem, User, Message])
        % mess_client ! {message_to, Elem, Message}
        end,
        List
    ).

logonAuto(Name, Password, Max) ->
    io:fwrite("@~p has logged on\n", [Name]),
    if
        Name == Max ->
            {fetch, server_node()} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
                % io:fwrite("Fol: ~p~n", [FollowersMap])
            end,
            {fetch, server_node()} ! {tweetmap, self()},
            receive
                {Tweet, All} ->
                    TweetsMap = Tweet
            end,
            {fetch, server_node()} ! {lstmsg, self()},
            receive
                {Last} ->
                    LastMap = Last
            end;
        true ->
            FollowersMap = persistent_term:get(folAuto),
            TweetsMap = persistent_term:get(tweetsAuto),
            LastMap = persistent_term:get(lastAuto)
    end,

    FollowersMap2 = #{Name => []},
    FollowersMap3 = maps:merge(FollowersMap2, FollowersMap),
    % io:fwrite("Fol: ~p~n", [FollowersMap3]),
    persistent_term:put(folAuto, FollowersMap3),
    % {messenger, server_node()} ! {update, FollowersMap3}.

    Temp_tweet = #{Name => []},

    NewTweetmp = maps:merge(TweetsMap, Temp_tweet),

    persistent_term:put(tweetsAuto, NewTweetmp),

    Temp_lsttweet = #{Name => ""},

    NewLastTweetmp = maps:merge(LastMap, Temp_lsttweet),

    persistent_term:put(lastAuto, NewLastTweetmp).

followAuto(User1, User2) ->
    % io:fwrite("User1: ~p User2: ~p~n", [User1, User2]),
    % {fetch, server_node()} ! {followmap, self()},
    % receive
    %     {Fol} ->
    %         FollowersMap = Fol,
    %         io:fwrite("Fol: ~p~n", [FollowersMap])
    % end,
    FollowersMap = persistent_term:get(folAuto),

    List = maps:get(User2, FollowersMap),
    List2 = lists:append(List, [User1]),
    FollowersMap2 = maps:update(User2, List2, FollowersMap),
    FollowersMap3 = maps:merge(FollowersMap, FollowersMap2),
    % io:fwrite("\nFol Map: ~p~n", [FollowersMap3]),
    persistent_term:put(folAuto, FollowersMap3).
% {messenger, server_node()} ! {update, FollowersMap3}.

main(N) ->
    for_reg(N),
    for_log(N, N),
    Half = N-5,
    for_follow(Half, N),

    for_off(N).

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

    % username => {Tuple of tweets}
    TweetsMap = #{},
    persistent_term:put(tweets, TweetsMap),

    % username => {tuple of users who are following username}
    FollowersMap = #{},
    persistent_term:put(followers, FollowersMap),

    % username => {tuple of users that username follows}
    FollowingMap = #{},
    persistent_term:put(following, FollowingMap),

    Alltweets = [],
    persistent_term:put(alltweets, Alltweets),

    Lastmsg = #{},
    persistent_term:put(lastmsg, Lastmsg),

    register(messenger, spawn(ttemp, server, [[]])),
    register(fetch, spawn(ttemp, datafetcher, [])).

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
            % Followers = #{Name => []},
            % persistent_term:put(followers, Followers),
            % persistent_term:put(user, Name),

            {fetch, server_node()} ! {user_list, self()},

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
                                spawn(ttemp, client, [server_node(), Name, Name])
                            );
                        true ->
                            io:fwrite("hatt")
                    end;
                true ->
                    io:fwrite("hatt")
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
            {fetch, server_node()} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
            end,

            mess_client ! {fetchmyname, self()},

            receive
                {Myname} ->
                    User = Myname
            end,

            {fetch, server_node()} ! {tweetmap, self()},
            receive
                {Tweetmp, Alt} ->
                    Tweetsmap = Tweetmp,
                    Alltweets = Alt
            end,

            % User = persistent_term:get(user),

            Newalltweets = lists:append(Alltweets, [Message]),

            List = maps:get(User, FollowersMap),

            Tweetlist = maps:get(User, Tweetsmap),

            Tweetlist2 = lists:append(Tweetlist, [Message]),

            Tweetmp1 = maps:update(User, Tweetlist2, Tweetsmap),
            % NewTweetmp = maps:merge(Tweetmp1, Tweetsmap),
            io:fwrite("~p", [Tweetmp1]),

            {messenger, server_node()} ! {tweetupd, Tweetmp1, Newalltweets},

            lists:foreach(
                fun(Elem) ->
                    io:fwrite("Elem: ~p~n", [Elem]),
                    mess_client ! {message_to, Elem, Message}
                end,
                List
            )
    end.

search(Query) ->
    {fetch, server_node()} ! {tweetmap, self()},
    receive
        {_Twtmp, Alt} ->
            Alltweets = Alt
    end,

    % mess_client ! {fetchmyname,self()},
    % receive
    %     {Myname}->
    %         User = Myname
    % end,
    % TweetsMap = persistent_term:get(tweets),
    % User = persistent_term:get(user),
    % Tweets = maps:get(User, TweetsMap),

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
        Alltweets
    ).

mention() ->
    {fetch, server_node()} ! {tweetmap, self()},
    receive
        {_Twtmp, Alt} ->
            Alltweets = Alt
    end,

    mess_client ! {fetchmyname, self()},
    receive
        {Myname} ->
            User = Myname
    end,
    % TweetsMap = persistent_term:get(tweets),
    % User = persistent_term:get(user),
    % Tweets = maps:get(User, TweetsMap),
    Query = "@" ++ atom_to_list(User),
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
        Alltweets
    ).

retweet() ->
    {fetch, server_node()} ! {lstmsg, self()},
    receive
        {Lst} ->
            Lastmsg = Lst
    end,

    mess_client ! {fetchmyname, self()},
    receive
        {Nm} ->
            Name = Nm
    end,

    Msg = maps:get(Name, Lastmsg),
    Retweet = "Re:" ++ Msg,
    io:fwrite("~p->~p->~p", [Retweet, Name, Lastmsg]),

    tweet(Retweet).

%%% The client process which runs on each server node
client(Server_Node, Name, Myname) ->
    {messenger, Server_Node} ! {self(), logon, Name},
    await_result(),
    client(Server_Node, Myname).

client(Server_Node, Myname) ->
    io:fwrite("~p~n", [Myname]),

    receive
        logoff ->
            {messenger, Server_Node} ! {self(), logoff},
            exit(normal);
        {message_to, ToName, Message} ->
            {messenger, Server_Node} ! {self(), message_to, ToName, Message},
            await_result();
        {message_from, FromName, Message} ->
            io:format("Message from ~p: ~p~n", [FromName, Message]),

            % fetch ! {lstmsg,self()},

            % receive
            %     {Lstmg}->
            %         Lastmsg = Lstmg
            % end,

            {messenger, Server_Node} ! {updlstmsg, Message, Myname};
        {follow_to, ToName} ->
            {messenger, Server_Node} ! {self(), follow_to, ToName},
            await_result();
        {follow_from, FromName} ->
            {fetch, Server_Node} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
            end,

            io:fwrite("~p", [FollowersMap]),
            List = maps:get(Myname, FollowersMap),
            List2 = lists:append(List, [FromName]),
            FollowersMap2 = maps:update(Myname, List2, FollowersMap),
            FollowersMap3 = maps:merge(FollowersMap, FollowersMap2),
            {messenger, Server_Node} ! {update, FollowersMap3};
        % persistent_term:put(followers, FollowersMap3),

        % receive
        %     {UserList}->
        %         io:fwrite("~p",[UserList])
        % end,
        % io:format("Follow from: ~p~n to : ~p~n", [FromName, Myname])
        % io:format("Followers: ~p~n", [FollowersMap3])
        {fetchmyname, From} ->
            From ! {Myname}
    end,
    client(Server_Node, Myname).

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