module Charts exposing (Hovered, view)

import Chart as C
import Chart.Attributes as CA
import Chart.Events as CE
import Chart.Item as CI
import Html as H
import Time exposing (Posix)


type alias Point =
    { date : Posix, total : Int }


type alias Hovered =
    CI.One Point CI.Any


type alias Config msg =
    { onHover : List Hovered -> msg
    , hovering : List Hovered
    , pointLabel : String
    }


view : Config msg -> List Point -> H.Html msg
view { hovering, onHover, pointLabel } events =
    C.chart
        [ CA.width 700
        , CA.height 400
        , CA.padding { top = 10, bottom = 25, left = 0, right = 25 }
        , CA.margin { top = 10, bottom = 0, left = 60, right = 10 }
        , CE.onMouseMove onHover (CE.getNearest CI.any)
        , CE.onMouseLeave (onHover [])
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
                [ C.interpolated (.total >> toFloat) [ CA.width 2 ] []
                    |> C.named pointLabel
                ]
        , C.each hovering <|
            \_ item ->
                [ C.tooltip item [] [] [] ]
        ]
