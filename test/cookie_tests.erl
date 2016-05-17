-module( cookie_tests ).
-author( "Warren Kenny <warren.kenny@gmail.com>" ).

-include_lib( "eunit/include/eunit.hrl" ).

deserialize_test() ->
	Headers = [
		{ <<"Set-Cookie">>, <<"cookie1=hello; expires=Wed, 17-May-2199 12:55:30 GMT; path=/; domain=.example.com; HttpOnly">> },
		{ <<"Set-Cookie">>, <<"cookie2=world; path=/; secure; SameSite=Strict">> }
	],
	{ ok, [ Cookie1, Cookie2 ] } = cookie:deserialize( Headers ),
	?assert( cookie:name( Cookie1 ) =:= <<"cookie1">> ),
	?assert( cookie:value( Cookie1 ) =:= <<"hello">> ),
	?assert( cookie:domain( Cookie1 ) =:= <<".example.com">> ),
	?assert( cookie:http_only( Cookie1 ) =:= true ),
	?assert( cookie:expired( Cookie1 ) =:= false ),
	
	?assert( cookie:name( Cookie2 ) =:= <<"cookie2">> ),
	?assert( cookie:value( Cookie2 ) =:= <<"world">> ),
	?assert( cookie:http_only( Cookie2 ) =:= false ),
	?assert( cookie:expired( Cookie1 ) =:= false ).
	
	
serialize_test() ->
	Headers = [
		{ <<"Set-Cookie">>, <<"cookie1=hello; expires=Wed, 17-May-2199 12:55:30 GMT; path=/; domain=.example.com; HttpOnly">> },
		{ <<"Set-Cookie">>, <<"cookie2=world; path=/; secure; HttpOnly; SameSite=Strict">> }
	],
	{ ok, [ Cookie1, Cookie2 ] } = cookie:deserialize( Headers ),
	?assert( cookie:serialize( [ Cookie1, Cookie2 ] ) =:= <<"cookie1=hello; cookie2=world">> ).