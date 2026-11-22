-module(volley_ffi).
-export([pdf_text/1]).

%% Inflates every Flate stream of a PDF and joins the ones that decode. Images
%% and fonts fail to inflate or hold no text operators, so they cost nothing.
pdf_text(Pdf) ->
    case re:run(Pdf, <<"stream\r?\n(.*?)\r?\nendstream">>,
                [global, dotall, {capture, all_but_first, binary}]) of
        {match, Streams} -> iolist_to_binary([inflate(S) || [S] <- Streams]);
        nomatch -> <<>>
    end.

inflate(Stream) ->
    try zlib:uncompress(Stream) catch _:_ -> <<>> end.
