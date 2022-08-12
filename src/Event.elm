module Event exposing
    ( Event
    , accumulate
    , countries
    , decodeList
    , formatCases
    , formatDate
    , fromCountry
    , sevenDaysAverage
    , sumByCountry
    , sumByDate
    , total
    )

import DateFormat
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import List.Extra as LE
import Set exposing (Set)
import Time exposing (Posix)


type alias Event =
    { date : Posix
    , country : String
    , cases : Float
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
        (Decode.field "ConfCases" Decode.float)


decodeList : Decoder (List Event)
decodeList =
    Decode.list decode


formatCases : Float -> String
formatCases n =
    if n - toFloat (round n) /= 0 then
        FormatNumber.format { usLocale | decimals = Exact 2 } n

    else
        String.fromFloat n


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


sumByCountry : List Event -> List ( String, Float )
sumByCountry =
    List.sortBy .country
        >> LE.groupWhile (\a b -> a.country == b.country)
        >> List.map
            (\( event, list ) ->
                ( event.country
                , event.cases + (list |> List.map .cases |> List.sum)
                )
            )
        >> List.sortBy Tuple.second
        >> List.reverse


sumByDate : String -> List Event -> List Event
sumByDate label =
    List.sortBy (.date >> Time.posixToMillis)
        >> LE.groupWhile (\a b -> a.date == b.date)
        >> List.map
            (\( event, list ) ->
                { event
                    | country = label
                    , cases = event.cases + (list |> List.map .cases |> List.sum)
                }
            )


sevenDaysAverage : String -> List Event -> List Event
sevenDaysAverage country events =
    events
        |> (if country == "Europe" then
                sumByDate "Europe"

            else
                fromCountry country
           )
        |> LE.greedyGroupsOfWithStep 7 1
        |> List.filter (List.length >> (==) 7)
        |> List.filterMap
            (\list ->
                list
                    |> List.reverse
                    |> List.head
                    |> Maybe.map
                        (\e ->
                            { e
                                | cases =
                                    (list |> List.map .cases |> List.sum)
                                        / toFloat (List.length list)
                            }
                        )
            )


total : List Event -> Maybe ( Posix, Float )
total =
    accumulate
        >> LE.last
        >> Maybe.map (\{ date, cases } -> ( date, cases ))
