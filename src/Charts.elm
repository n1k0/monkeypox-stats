module Charts exposing (view)

-- import Svg as S

import Chart as C
import Chart.Attributes as CA
import Html as H
import Time exposing (Posix)


view : List { date : Posix, total : Int } -> H.Html msg
view events =
    C.chart
        [ CA.width 700
        , CA.height 400
        , CA.padding { top = 10, bottom = 25, left = 0, right = 25 }
        , CA.margin { top = 10, bottom = 0, left = 60, right = 10 }
        , CA.range
            [ CA.lowest
                (events
                    |> List.map (.date >> Time.posixToMillis >> toFloat)
                    |> List.minimum
                    |> Maybe.withDefault 0
                )
                CA.exactly
            , CA.highest
                (events
                    |> List.map (.date >> Time.posixToMillis >> toFloat)
                    |> List.maximum
                    |> Maybe.withDefault 0
                )
                CA.exactly
            ]
        ]
        [ C.xAxis []
        , C.xTicks [ CA.times Time.utc ]
        , C.xLabels [ CA.times Time.utc ]
        , C.yLabels [ CA.withGrid ]
        , events
            |> C.series (.date >> Time.posixToMillis >> toFloat)
                [ C.interpolated (.total >> toFloat) [] []
                ]
        ]
