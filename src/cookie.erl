-module( cookie ).
-author( "Warren Kenny <warren.kenny@gmail.com>" ).

%% Accessors
-export( [name/1, value/1, expires/1, expired/1, max_age/1, secure/1, path/1, domain/1, http_only/1] ).
%% Serialization
-export( [deserialize/1, serialize/1, merge/2] ).

-type timestamp() :: integer().

%%
%%  Cookie record
%%
-record( cookie, {	name 		= undefined :: binary(),
					value 		= undefined :: binary(),
					expires 	= undefined :: integer(),
					max_age 	= undefined :: integer(),
					secure 		= false     :: boolean(),
					path 		= <<"/">>   :: binary(),
					domain 		= undefined :: binary(),
					http_only 	= false     :: boolean()
} ).

%%
%%  Accessors
%%
name( #cookie{ name = N } )             -> N.
value( #cookie{ value = V } )           -> V.
expires( #cookie{ expires = E } )       -> E.
max_age( #cookie{ max_age = M } )       -> M.
secure( #cookie{ secure = S } )         -> S.
path( #cookie{ path = P } )             -> P.
domain( #cookie{ domain = D } )         -> D.
http_only( #cookie{ http_only = H } )   -> H.

%%
%%  Check whether this cookie has expired
%%
expired( #cookie{ max_age = M } ) when is_integer( M ) ->
    expired( M );
    
expired( #cookie{ expires = E } ) when is_integer( E ) ->
    expired( E );
    
expired( #cookie{} ) -> false;
    
expired( Timestamp ) when is_integer( Timestamp ) ->
    erlang:system_time( seconds ) > Timestamp.

%%
%%  Convert an expires or max-age value into a timestamp
%%
-spec timestamp( string() | integer() ) -> timestamp().
timestamp( DateTime ) when is_list( DateTime ) -> 
    { Mega, Sec, Micro } = ec_date:nparse( DateTime ),
    ( Mega * 1000000 + Sec ) * 1000 + round( Micro / 1000 );

timestamp( Seconds ) -> 
    erlang:system_time( seconds ) + Seconds.



%%
%%  Parse the initial name-value pair from the given cookie string and then proceed to attribute parsing
%%
-spec parse_name_value( string(), #cookie{} ) -> { ok, #cookie{} } | { error, term() }.
parse_name_value( [ NameValue | Attributes ], Cookie = #cookie{} ) ->
    case string:tokens( NameValue, "=" ) of
        [ Name, Value ] -> parse_attributes( Attributes, Cookie#cookie{ name = want:binary( Name ), value = want:binary( Value ) } );
        _               -> { error, missing_name_value }
    end;
    
parse_name_value( [], _ ) -> { error, invalid_cookie_format }.

%%
%%  Parse recognizable attributes from the given cookie tokens
%%
-spec parse_attributes( [ string() ], #cookie{} ) -> { ok, #cookie{} } | { error, term() }.
parse_attributes( [ [ $p, $a, $t, $h, $= | Path ] | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ path = want:binary( Path ) } );
    
parse_attributes( [ [ $e, $x, $p, $i, $r, $e, $s, $= | Expires ] | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ expires = timestamp( Expires ) } );
    
parse_attributes( [ [ $m, $a, $x, $-, $a, $g, $e, $= | MaxAge ] | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ max_age = timestamp( MaxAge ) } );
    
parse_attributes( [ [ $d, $o, $m, $a, $i, $n, $= | Domain ] | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ domain = want:binary( Domain ) } );
    
parse_attributes( [ "secure" | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ secure = true } );
    
parse_attributes( [ "HttpOnly" | T ], Cookie ) ->
    parse_attributes( T, Cookie#cookie{ http_only = true } );
    
parse_attributes( [ _Unknown | T ], Cookie ) ->
    parse_attributes( T, Cookie );
    
parse_attributes( [], Cookie ) -> { ok, Cookie }.
    
%%
%%  Given a proplist containing server response headers, deserialize and return a list
%%  of cookies by parsing Set-Cookie headers.
%%
-spec deserialize( [ { binary(), binary() }] ) -> { ok, [#cookie{}] } | { error, term() }.
deserialize( Headers ) ->
    deserialize( Headers, [] ).

-spec deserialize( [ { binary(), binary() } ], [#cookie{}] ) -> { ok, [#cookie{}] } | { error, term() }.
deserialize( [ { <<"Set-Cookie">>, Cookie } | Rest ], Out ) ->
    case parse_name_value( [ string:strip( S ) || S <- string:tokens( want:string( Cookie ), ";" ) ], #cookie{} ) of
        { ok, Deserialized }    -> deserialize( Rest, [ Deserialized | Out ] );
        { error, Reason }       -> { error, Reason }
    end;
    
deserialize( [ { <<"set-cookie">>, Cookie } | Rest ], Out ) ->
    deserialize( [ { <<"Set-Cookie">>, Cookie } | Rest ], Out );
    
deserialize( [ { _Key, _Value } | Rest ], Out ) ->
    deserialize( Rest, Out );
    
deserialize( [], Out ) ->
    { ok, lists:reverse( Out ) }.
    
%%
%%  Serialize the given cookies into a form suitable for inclusion in a 'cookie' header
%%
-spec serialize( [#cookie{}] ) -> binary().
serialize( Cookies ) ->
    want:binary( string:join( [ string:join( [  want:string( Name ), 
                                                want:string( Value ) ], "=" ) || #cookie{ name = Name, value = Value } <- Cookies ], "; " ) ).
                      
%%
%%  Merge a new set of cookies into an old one, overwriting any cookies with matching names in the old set. 
%%
-spec merge( [#cookie{}], [#cookie{}] ) -> [#cookie{}].
merge( Old, New ) ->
    Sort = fun( A, B ) -> want:string( name( A ) ) =< want:string( name( B ) ) end,
    lists:usort( Sort, lists:merge( Sort, lists:sort( Sort, New ), lists:sort( Sort, Old ) ) ).    