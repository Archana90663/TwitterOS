-module(twitter).
-compile(export_all).




%________________________________________________SERVER_____________________________________________________

master_node() -> %The node of the server
    'twitter@Harshs-MacBook-Air'.
master(User_List) -> %Function that runs server
    receive
        {From, login, Name} ->
            New_User_List = master_login(From, Name, User_List),
            master(New_User_List);
        {From, logoff} ->
            New_User_List = master_logoff(From, User_List),
            master(New_User_List);
        {From, message_to, To, Message} ->
            master_transfer(From, To, Message, User_List),
            io:format("list is now: ~p~n", [User_List]),
            master(User_List);
        {From, follow_to, To} ->
            master_follow(From, To, User_List),
            master(User_List);
        {user_list, Pid} ->
            io:fwrite("~p", Pid);
        %used to register a new user and initializes all the data structures utilized by the user in the twitter app
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

        {update, Followmp} -> %updates the followers map every time a user follows other user
            persistent_term:put(followers, Followmp);
        % io:fwrite("~p",[Followmp]);
        {tweetupd, Tweetmap, Alltweets} -> %updates the tweet map as they are made by the user 
            io:fwrite("~p", [Tweetmap]),
            persistent_term:put(alltweets, Alltweets),
            persistent_term:put(tweets, Tweetmap);
        {updlstmsg, Message, Name} -> %updates the last tweet received by every user
            Lastmsg = persistent_term:get(lastmsg),
            Lastmsg2 = maps:update(Name, Message, Lastmsg),
            persistent_term:put(lastmsg, Lastmsg2)
    end,
    master(User_List).

%helper funtion that helps in fetching data from master.
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
%_________________________________________________________SIMULATOR________________________________________________


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
    loginAuto(N, N, Max),
    for_log(N - 1, Max).

for_follow(0, Max) ->
    io:fwrite("\n"),
    ok;
for_follow(N, Max) ->
    User1 = rand:uniform(N),
    User2 = getRandom(User1, Max),
    persistent_term:put(user, User1),

    followAuto(User1, User2),
    for_tweet(User2, "Sample Tweet", 1),

    for_follow(N - 1, Max).

for_tweet(User, Msg, 0) ->
    ok;
for_tweet(User, Msg, N) ->
    tweetAuto(User, Msg),
    for_tweet(User, Msg, N - 1).

for_off(0) ->
    {_, Time1} = statistics(runtime),
    {_, Time2} = statistics(wall_clock),
    U1 = Time1 * 10000,
    U2 = Time2 * 1000,
    io:format("Code time=~p (~p)~n", [U2, U1]),
    io:format("Ratio = ~p", [U2 / U1]),
    ok;
for_off(N) ->
    logoffAuto(N, N),
    for_off(N - 1).

logoffAuto(N, N) ->
    {fetch, master_node()} ! {user_list, self()},

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
   
    {fetch, master_node()} ! {tweetmap, self()},
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

    {twitter, master_node()} ! {tweetupd, Tweetmp1, Newalltweets},

    lists:foreach(
        fun(Elem) ->
            io:fwrite("~p~n User~p to User~p ", [Elem, User, Message])
        % mess_worker ! {message_to, Elem, Message}
        end,
        List
    ).

loginAuto(Name, Password, Max) ->
    io:fwrite("Login Done -> User~p \n", [Name]),
    if
        Name == Max ->
            {fetch, master_node()} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
                % io:fwrite("Fol: ~p~n", [FollowersMap])
            end,
            {fetch, master_node()} ! {tweetmap, self()},
            receive
                {Tweet, All} ->
                    TweetsMap = Tweet
            end,
            {fetch, master_node()} ! {lstmsg, self()},
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
    % {messenger, master_node()} ! {update, FollowersMap3}.

    Temp_tweet = #{Name => []},

    NewTweetmp = maps:merge(TweetsMap, Temp_tweet),

    persistent_term:put(tweetsAuto, NewTweetmp),

    Temp_lsttweet = #{Name => ""},

    NewLastTweetmp = maps:merge(LastMap, Temp_lsttweet),

    persistent_term:put(lastAuto, NewLastTweetmp).

followAuto(User1, User2) ->
    % io:fwrite("User1: ~p User2: ~p~n", [User1, User2]),
    % {fetch, master_node()} ! {followmap, self()},
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
% {messenger, master_node()} ! {update, FollowersMap3}.

main(N) -> % starts the simulator
    statistics(runtime),
    statistics(wall_clock),
    for_reg(N),
    for_log(N, N),
    Half = N - 5,
    for_follow(Half, N),

    for_off(N).

%_____________________________________________________________________________________________

% Starts the master
start_master() ->
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

    register(twitter, spawn(twitter, master, [[]])),
    register(fetch, spawn(twitter, datafetcher, [])).


% login function checks if user is registered and then logs the user in 
master_login(From, Name, User_List) ->
    
    case lists:keymember(Name, 2, User_List) of
        true ->
            %reject login
            From ! {twitter, stop, user_exists_at_other_node},
            User_List;
        false ->
            From ! {twitter, logged_on},
            %add user to the list
            [{From, Name} | User_List]
    end.

% logs the user off 
master_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).

master_follow(From, To, User_List) -> % used to follow other users on the network.
  
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {twitter, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            master_follow(From, Name, To, User_List)
    end.

master_follow(From, Name, To, User_List) ->
    
    case lists:keysearch(To, 2, User_List) of
        false ->
            From ! {twitter, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {follow_from, Name},
            From ! {twitter, sent}
    end.


master_transfer(From, To, Message, User_List) ->
    
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {twitter, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            master_transfer(From, Name, To, Message, User_List)
    end.

master_transfer(From, Name, To, Message, User_List) ->
    %% Find the receiver and send the message
    case lists:keysearch(To, 2, User_List) of
        false ->
            From ! {twitter, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_from, Name, Message},
            From ! {twitter, sent}
    end.


%______________________________________________________CLIENT____________________________________________

% registers the user
reg(Username, Password) ->
    {twitter, master_node()} ! {register, self(), "df", Username, Password}.

login(Name, Password) -> % logs in the user
    case whereis(mess_worker) of
        undefined ->
           

            {fetch, master_node()} ! {user_list, self()},

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
                                mess_worker,
                                spawn(twitter, worker, [master_node(), Name, Name])
                            );
                        true ->
                            io:fwrite("")
                    end;
                true ->
                    io:fwrite("")
            end;
        _ ->
            already_logged_on
    end.

logoff() ->
    mess_worker ! logoff.

follow(ToName) ->
    case whereis(mess_worker) of
        undefined ->
            not_logged_on;
        _ ->
            mess_worker ! {follow_to, ToName},
            ok
    end.

message(ToName, Message) ->
    % Test if the worker is running
    case whereis(mess_worker) of
        undefined ->
            not_logged_on;
        _ ->
            mess_worker ! {message_to, ToName, Message},
            ok
    end.

tweet(Message) -> %tweets new tweet
  
    case whereis(mess_worker) of
        undefined ->
            not_logged_on;
        _ ->
            {fetch, master_node()} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
            end,

            mess_worker ! {fetchmyname, self()},

            receive
                {Myname} ->
                    User = Myname
            end,

            {fetch, master_node()} ! {tweetmap, self()},
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

            {twitter, master_node()} ! {tweetupd, Tweetmp1, Newalltweets},

            lists:foreach(
                fun(Elem) ->
                    io:fwrite("Elem: ~p~n", [Elem]),
                    mess_worker ! {message_to, Elem, Message}
                end,
                List
            )
    end.

search(Query) -> % search for hashtags in the database of all tweets 
    {fetch, master_node()} ! {tweetmap, self()},
    receive
        {_Twtmp, Alt} ->
            Alltweets = Alt
    end,

    % mess_worker ! {fetchmyname,self()},
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

mention() -> % each user can search the tweets in which he has been mentioned
    {fetch, master_node()} ! {tweetmap, self()},
    receive
        {_Twtmp, Alt} ->
            Alltweets = Alt
    end,

    mess_worker ! {fetchmyname, self()},
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

retweet() -> % retweet tweets the last tweets received by the user 
    {fetch, master_node()} ! {lstmsg, self()},
    receive
        {Lst} ->
            Lastmsg = Lst
    end,

    mess_worker ! {fetchmyname, self()},
    receive
        {Nm} ->
            Name = Nm
    end,

    Msg = maps:get(Name, Lastmsg),
    Retweet = "Retweeted Message" ++ Msg,
    io:fwrite("~p->~p->~p", [Retweet, Name, Lastmsg]),

    tweet(Retweet).


worker(Master_Node, Name, Myname) -> % this is the client 
    {twitter, Master_Node} ! {self(), login, Name},
    wait(),
    worker(Master_Node, Myname).

worker(Master_Node, Myname) ->
    io:fwrite("~p~n", [Myname]),

    receive
        logoff ->
            {twitter, Master_Node} ! {self(), logoff},
            exit(bas);
        {message_to, ToName, Message} ->
            {twitter, Master_Node} ! {self(), message_to, ToName, Message},
            wait();
        {message_from, FromName, Message} ->
            io:format("Tweeted by ~p: ~p~n", [FromName, Message]),

            % fetch ! {lstmsg,self()},

            % receive
            %     {Lstmg}->
            %         Lastmsg = Lstmg
            % end,

            {twitter, Master_Node} ! {updlstmsg, Message, Myname};
        {follow_to, ToName} ->
            {twitter, Master_Node} ! {self(), follow_to, ToName},
            wait();
        {follow_from, FromName} ->
            {fetch, Master_Node} ! {followmap, self()},
            receive
                {Fol} ->
                    FollowersMap = Fol
            end,

            io:fwrite("~p", [FollowersMap]),
            List = maps:get(Myname, FollowersMap),
            List2 = lists:append(List, [FromName]),
            FollowersMap2 = maps:update(Myname, List2, FollowersMap),
            FollowersMap3 = maps:merge(FollowersMap, FollowersMap2),
            {twitter, Master_Node} ! {update, FollowersMap3};
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
    worker(Master_Node, Myname).

%%% wait for a response from the master
wait() ->
    receive
        % Stop the worker
        {twitter, stop, Why} ->
            io:format("~p~n", [Why]),
            exit(bas);
        % Normal response
        {twitter, What} ->
            io:format("~p~n", [What])
    end.