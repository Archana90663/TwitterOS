

plugins:
	@(export PATH=`pwd`/`echo erts-*/bin`:$$PATH;escript do-plugins.escript)



copy-static:
	@(cp -r lib/nitrogen_core/www/* priv/static//nitrogen/)

run:
    erl -pa ebin/ deps/*/ebin/ -eval "application:start(twitter)"