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


fromCountry : String -> List Event -> List Event
fromCountry country =
    List.filter (.country >> (==) country)


total : List Event -> Maybe ( Posix, Int )
total =
    accumulate
        >> LE.last
        >> Maybe.map (\{ date, cases } -> ( date, cases ))
