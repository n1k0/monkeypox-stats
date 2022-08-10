module Charts exposing (view, view2)

-- import Svg as S

import Chart as C
import Chart.Attributes as CA
import Html as H
import Time exposing (Posix)


view : List { date : Float, total : Float } -> H.Html msg
view events =
    C.chart
        [ CA.width 700
        , CA.height 400
        , CA.padding { top = 10, bottom = 25, left = 0, right = 25 }
        , CA.margin { top = 10, bottom = 0, left = 60, right = 10 }
        , CA.range
            [ CA.lowest
                (events
                    |> List.map .date
                    |> List.minimum
                    |> Maybe.withDefault 0
                )
                CA.exactly
            , CA.highest
                (events
                    |> List.map .date
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
            |> C.series .date
                [ C.interpolated .total [] []
                ]
        ]


view2 : H.Html msg
view2 =
    C.chart
        [ CA.height 300
        , CA.width 300
        ]
        [ C.xLabels []
        , C.yLabels [ CA.withGrid ]
        , data
            |> C.series .x
                [ C.interpolated .y [ CA.monotone ] []
                ]
        ]


type alias Datum =
    { x : Float
    , y : Float
    , z : Float
    , v : Float
    , w : Float
    , p : Float
    , q : Float
    }


data : List Datum
data =
    [ Datum 1 2 1 4.6 6.9 7.3 8.0
    , Datum 2 3 2 5.2 6.2 7.0 8.7
    , Datum 3 4 3 5.5 5.2 7.2 8.1
    , Datum 4 3 4 5.3 5.7 6.2 7.8
    , Datum 5 2 3 4.9 5.9 6.7 8.2
    , Datum 6 4 1 4.8 5.4 7.2 8.3
    , Datum 7 5 2 5.3 5.1 7.8 7.1
    , Datum 8 6 3 5.4 3.9 7.6 8.5
    , Datum 9 5 4 5.8 4.6 6.5 6.9
    , Datum 10 4 3 4.5 5.3 6.3 7.0
    ]
