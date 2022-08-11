module Event exposing
    ( Event
    , accumulate
    , countries
    , decodeList
    , formatDate
    , fromCountry
    , sumByDate
    , total
    )

import DateFormat
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import List.Extra as LE
import Set exposing (Set)
import Time exposing (Posix)


type alias Event =
    { date : Posix
    , country : String
    , cases : Int
    }


accumulate : List Event -> List Event
accumulate =
    List.foldl
        (\event acc ->
            { event
                | cases =
                    event.cases
                        + (acc
                            |> List.head
                            |> Maybe.map .cases
                            |> Maybe.withDefault 0
                          )
            }
                :: acc
        )
        []
        >> List.reverse


countries : List Event -> Set String
countries =
    List.map .country >> Set.fromList


decode : Decoder Event
decode =
    Decode.map3 Event
        (Decode.field "DateRep" Iso8601.decoder)
        (Decode.field "CountryExp" Decode.string)
        (Decode.field "ConfCases" Decode.int)


decodeList : Decoder (List Event)
decodeList =
    Decode.list decode


formatDate : Posix -> String
formatDate =
    DateFormat.format
        [ DateFormat.monthNameAbbreviated
        , DateFormat.text " "
        , DateFormat.dayOfMonthSuffix
        , DateFormat.text ", "
        , DateFormat.yearNumber
        ]
        Time.utc


fromCountry : String -> List Event -> List Event
fromCountry country =
    List.filter (.country >> (==) country)


sumByDate : String -> List Event -> List Event
sumByDate label events =
    events
        |> List.sortBy (.date >> Time.posixToMillis)
        |> LE.groupWhile (\a b -> a.date == b.date)
        |> List.map
            (\( event, list ) ->
                { event
                    | country = label
                    , cases = event.cases + (list |> List.map .cases |> List.sum)
                }
            )


total : List Event -> Maybe ( Posix, Int )
total =
    accumulate
        >> LE.last
        >> Maybe.map (\{ date, cases } -> ( date, cases ))
