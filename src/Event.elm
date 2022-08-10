module Event exposing
    ( Event
    , accumulate
    , fromCountry
    , total
    )

import List.Extra as LE
import Time exposing (Posix)


type alias Event =
    { date : Posix
    , country : String
    , newCases : Int
    }


accumulate : List Event -> List ( Int, Event )
accumulate =
    List.foldl
        (\event acc ->
            ( event.newCases
                + (acc
                    |> List.head
                    |> Maybe.map Tuple.first
                    |> Maybe.withDefault 0
                  )
            , event
            )
                :: acc
        )
        []
        >> List.reverse


fromCountry : String -> List Event -> List Event
fromCountry country =
    List.filter (.country >> (==) country)


total : List Event -> Maybe ( Posix, Int )
total events =
    events
        |> accumulate
        |> LE.last
        |> Maybe.map (\( tot, { date } ) -> ( date, tot ))
