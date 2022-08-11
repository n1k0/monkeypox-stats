module Main exposing (main)

import Browser exposing (Document)
import Charts
import Dict exposing (Dict)
import Event exposing (Event)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Set
import Time


type alias Model =
    { mode : Mode
    , events : List Event
    , hovering : Dict String (List Charts.Hovered)
    }


type Msg
    = DataReceived (Result Http.Error (List Event))
    | OnHover String (List Charts.Hovered)
    | SwitchMode Mode


type Mode
    = Cumulative
    | PerDay
    | SevenDaysAverage


init : () -> ( Model, Cmd Msg )
init _ =
    ( { mode = Cumulative
      , events = []
      , hovering = Dict.fromList []
      }
    , Http.get
        { url = dataUrl
        , expect = Http.expectJson DataReceived Event.decodeList
        }
    )


dataUrl : String
dataUrl =
    "https://opendata.ecdc.europa.eu/monkeypox/casedistribution/json/data.json"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DataReceived (Ok events) ->
            ( { model | events = events }, Cmd.none )

        DataReceived (Err _) ->
            ( model, Cmd.none )

        OnHover country hovering ->
            ( { model
                | hovering =
                    model.hovering
                        |> Dict.insert country hovering
              }
            , Cmd.none
            )

        SwitchMode mode ->
            ( { model | mode = mode }, Cmd.none )


type alias CardConfig =
    { country : Maybe String
    , events : List Event
    , mode : Mode
    , hovering : Dict String (List Charts.Hovered)
    , width : Float
    , height : Float
    }


viewCard : CardConfig -> Html Msg
viewCard { country, events, hovering, mode, width, height } =
    let
        ( selectedEvents, countryId ) =
            case country of
                Just c ->
                    ( Event.fromCountry c events, c )

                Nothing ->
                    ( Event.sumByDate "Europe" events, "Europe" )
    in
    div [ class "card h-100" ]
        [ div [ class "card-header d-flex justify-content-between" ]
            [ span [] [ country |> Maybe.withDefault "Europe" |> text ]
            , span []
                [ case Event.total selectedEvents of
                    Just ( date, tot ) ->
                        small [ class "text-muted fs-7 ms-2" ]
                            [ text <| String.fromFloat tot ++ " tot. on " ++ Event.formatDate date ]

                    Nothing ->
                        text ""
                ]
            ]
        , div [ class "card-body" ]
            [ selectedEvents
                |> (case mode of
                        Cumulative ->
                            Event.accumulate

                        PerDay ->
                            identity

                        SevenDaysAverage ->
                            Event.sevenDaysAverage countryId
                   )
                |> Charts.view
                    { hovering = hovering |> Dict.get countryId |> Maybe.withDefault []
                    , onHover = OnHover countryId
                    , width = width
                    , height = height
                    }
            ]
        ]


view : Model -> Document Msg
view model =
    let
        allEvents =
            model.events
                |> List.sortBy (.date >> Time.posixToMillis)
    in
    { title = "Monkeypox stats EU"
    , body =
        [ div [ class "container py-4" ]
            [ h1 [ class "mb-3" ] [ text "Monkeypox stats for EU" ]
            , div [ class "row" ]
                [ div [ class "col-md-8" ]
                    [ case Event.total allEvents of
                        Just ( date, tot ) ->
                            p [ class "text-muted fw-bold" ]
                                [ text <|
                                    String.fromFloat tot
                                        ++ " total confirmed cases as of "
                                        ++ Event.formatDate date
                                        ++ " in Europe — Source: "
                                , a [ href "https://www.ecdc.europa.eu/en/publications-data/data-monkeypox-cases-eueea" ]
                                    [ text "ECDC" ]
                                ]

                        Nothing ->
                            text ""
                    ]
                , [ ( Cumulative, "Cumulative" )
                  , ( PerDay, "Per-day" )
                  , ( SevenDaysAverage, "7 days average" )
                  ]
                    |> List.map
                        (\( mode, caption ) ->
                            label [ class "form-check-label" ]
                                [ input
                                    [ type_ "radio"
                                    , class "form-check-input"
                                    , name "mode"
                                    , checked <| model.mode == mode
                                    , onCheck (always (SwitchMode mode))
                                    ]
                                    []
                                , span [ class "ms-2" ] [ text caption ]
                                ]
                        )
                    |> div [ class "col-md-4 d-flex justify-content-center justify-content-md-end gap-4" ]
                ]
            , viewCard
                { country = Nothing
                , events = model.events
                , mode = model.mode
                , hovering = model.hovering
                , width = 450 * 3
                , height = 280 * 2
                }
            , Event.countries allEvents
                |> Set.toList
                |> List.map
                    (\country ->
                        div [ class "col" ]
                            [ viewCard
                                { country = Just country
                                , events = model.events
                                , mode = model.mode
                                , hovering = model.hovering
                                , width = 450
                                , height = 280
                                }
                            ]
                    )
                |> div [ class "row row-cols-1 row-cols-sm-2 row-cols-lg-3 g-4 my-3" ]
            , p [ class "d-flex justify-content-center gap-5" ]
                [ a [ href "https://www.ecdc.europa.eu/en/publications-data/data-monkeypox-cases-eueea" ]
                    [ text "Data source" ]
                , a [ href "https://github.com/n1k0/monkeypox-stats" ] [ text "Source code" ]
                , a [ href "https://nicolas.perriault.net" ] [ text "Author" ]
                ]
            ]
        ]
    }


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }
