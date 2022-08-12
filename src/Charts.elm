module Charts exposing (Hovered, bars, line)

import Chart as C
import Chart.Attributes as CA
import Chart.Events as CE
import Chart.Item as CI
import Event exposing (Event)
import Html as H
import Html.Attributes as HA
import Svg.Attributes as SA
import Time


bars : { width : Float, height : Float } -> List ( String, Float ) -> H.Html msg
bars { width, height } data =
    C.chart
        [ CA.padding { top = 20, bottom = 75, left = 0, right = 25 }
        , CA.margin { top = 10, bottom = 0, left = 60, right = 10 }
        , CA.width width
        , CA.height height
        ]
        [ C.yLabels [ CA.withGrid ]
        , C.binLabels Tuple.first
            [ CA.moveDown 10
            , CA.moveRight 4
            , CA.rotate 45
            , CA.attrs
                [ SA.style "text-anchor: end"
                ]
            ]
        , C.bars []
            [ C.bar Tuple.second []
                |> C.named "plop"
            ]
            data
        ]


type alias Hovered =
    CI.One Event CI.Any


type alias LineConfig msg =
    { onHover : List Hovered -> msg
    , hovering : List Hovered
    , width : Float
    , height : Float
    }


line : LineConfig msg -> List Event -> H.Html msg
line { hovering, onHover, width, height } events =
    C.chart
        [ CA.width width
        , CA.height height
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
                [ C.interpolated .cases [ CA.width 2 ] []
                ]
        , C.each hovering <|
            \_ item ->
                let
                    ( event, color ) =
                        ( CI.getData item, CI.getColor item )
                in
                [ C.tooltip item [] [] [ tooltip color event ]
                ]
        ]


tooltip : String -> Event -> H.Html msg
tooltip color { country, date, cases } =
    H.span []
        [ H.div []
            [ H.text (Event.formatDate date) ]
        , H.div []
            [ H.text country
            , H.span [ HA.style "color" color ]
                [ H.text ": "
                , H.text (Event.formatCases cases)
                , H.text <|
                    " case"
                        ++ (if cases == 1 then
                                ""

                            else
                                "s"
                           )
                ]
            ]
        ]
