module EventTest exposing (..)

import Event exposing (Event)
import Expect
import Test exposing (Test, describe, test)
import Time


suite : Test
suite =
    describe "sevenDaysAverage"
        [ test "should compute a 7 days average timeserie" <|
            \_ ->
                List.range 1 10
                    |> List.map (\x -> Event (Time.millisToPosix x) "France" (toFloat x))
                    |> Event.sevenDaysAverage "France"
                    |> List.map (\{ date, cases } -> ( Time.posixToMillis date, cases ))
                    |> Expect.equal
                        [ ( 7, (1 + 2 + 3 + 4 + 5 + 6 + 7) / 7 )
                        , ( 8, (2 + 3 + 4 + 5 + 6 + 7 + 8) / 7 )
                        , ( 9, (3 + 4 + 5 + 6 + 7 + 8 + 9) / 7 )
                        , ( 10, (4 + 5 + 6 + 7 + 8 + 9 + 10) / 7 )
                        ]
        ]
