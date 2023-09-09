-module(tweeter).
-compile(export_all).

start() ->
    % List of all users
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
    persistent_term:put(following, FollowingMap).

register(Username, Password) ->
    Temp = #{Username => Password},

    Userdat = persistent_term:get(userdata),

    NewUserdat = maps:merge(Temp, Userdat),

    persistent_term:put(userdata, NewUserdat),

    Tweettmp = #{Username => {}},

    Tweetmap = persistent_term:get(tweets),

    NewTweetmap = maps:merge(Tweettmp, Tweetmap),

    persistent_term:put(tweets, NewTweetmap),

    Followtmp = #{Username => {}},

    Followersmap = persistent_term:get(followers),

    NewFollowers = maps:merge(Followtmp, Followersmap),

    persistent_term:put(followers, NewFollowers),

    Followingtmp = #{Username => {}},

    Followingsmap = persistent_term:get(followers),

    NewFollowing = maps:merge(Followingtmp, Followingsmap),

    persistent_term:put(following, NewFollowing).

login(Username, Password) ->
    Userdata = persistent_term:get(userdata),
    Booluser = maps:is_key(Username, Userdata),

    if
        Booluser == true ->
            Pass = maps:get(Username, Userdata),

            if
                Password == Pass ->
                    Pid = spawn(tweeter, twitter, []),
                    Usertopid = persistent_term:get(usertopid),
                    Usertopid2 = #{Username => Pid},
                    Usertopid3 = maps:merge(Usertopid, Usertopid2),
                    persistent_term:put(usertopid, Usertopid3),
                    io:fwrite("Usertopid: ~p~n", [Usertopid3]),

                    io:fwrite("Logged in");
                true ->
                    io:fwrite("hatt")
            end;
        true ->
            io:fwrite("df")
    end.

twitter() ->
    io:fwrite("dfhgd").

subscribe(Username, Follow) ->
    FollowersMap = persistent_term:get(followers),
    Followers = tuple_to_list(maps:get(Follow, FollowersMap)),
    Bool = lists:member(Username, Followers),

    if
        Bool == false ->
            Followers2 = lists:append([Username], Followers),
            FollowersMap2 = maps:update(Follow, list_to_tuple(Followers2), FollowersMap),
            persistent_term:put(followers, FollowersMap2),

            FollowingMap = persistent_term:get(following),
            Following = tuple_to_list(maps:get(Username, FollowingMap)),
            Following2 = lists:append([Follow], Following),
            FollowingMap2 = maps:update(Username, list_to_tuple(Following2), FollowingMap),
            persistent_term:put(following, FollowingMap2),

            io:fwrite("~p~n, has subscribed to ~p~n", [Username, Follow]);
        true ->
            ok
    end.

sendTweet(Username, Tweet) ->
    FollowersMap = persistent_term:get(followers),
    Followers = tuple_to_list(maps:get(Username, FollowersMap)),
    io:fwrite("Follow: ~p~n", [Followers]),

    Usertopid = persistent_term:get(usertopid),
    io:fwrite("Sending usertopid: ~p~n", [Usertopid]),

    lists:foreach(
        fun(Elem) ->
            Bool = maps:is_key(Elem, Usertopid),
            if
                Bool == true ->
                    io:fwrite("Elem: ~p~n", [Elem]),
                    Pid = maps:get(Elem, Usertopid),
                    Pid ! {Tweet};
                true ->
                    ok
            end
        end,
        Followers
    ).