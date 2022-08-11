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


viewCountry : Model -> String -> Html Msg
viewCountry { hovering, events, mode } country =
    let
        countryEvents =
            events
                |> Event.fromCountry country
    in
    div [ class "col" ]
        [ div [ class "card h-100" ]
            [ div [ class "card-header d-flex justify-content-between" ]
                [ span [] [ text country ]
                , span []
                    [ case Event.total countryEvents of
                        Just ( date, tot ) ->
                            small [ class "text-muted fs-7 ms-2" ]
                                [ text <| String.fromInt tot ++ " tot. on " ++ Event.formatDate date ]

                        Nothing ->
                            text ""
                    ]
                ]
            , div [ class "card-body p-2" ]
                [ countryEvents
                    |> (case mode of
                            Cumulative ->
                                Event.accumulate

                            PerDay ->
                                identity
                       )
                    |> Charts.view
                        { hovering = hovering |> Dict.get country |> Maybe.withDefault []
                        , onHover = OnHover country
                        , pointLabel = "Confirmed cases"
                        , width = 450
                        , height = 280
                        }
                ]
            ]
        ]


viewEurope : Model -> Html Msg
viewEurope { events, hovering, mode } =
    div [ class "card my-3" ]
        [ div [ class "card-header" ] [ text "Europe" ]
        , div [ class "card-body" ]
            [ events
                |> (case mode of
                        Cumulative ->
                            Event.accumulate

                        PerDay ->
                            identity
                   )
                |> Charts.view
                    { hovering = hovering |> Dict.get "" |> Maybe.withDefault []
                    , onHover = OnHover ""
                    , pointLabel = "Confirmed cases"
                    , width = 450 * 3
                    , height = 280 * 2
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
                                    String.fromInt tot
                                        ++ " total confirmed cases as of "
                                        ++ Event.formatDate date
                                        ++ " in Europe — Source: "
                                , a [ href "https://www.ecdc.europa.eu/en/publications-data/data-monkeypox-cases-eueea" ]
                                    [ text "ECDC" ]
                                ]

                        Nothing ->
                            text ""
                    ]
                , div [ class "col-md-4 d-flex justify-content-center justify-content-md-end gap-4" ]
                    [ label [ class "form-check-label" ]
                        [ input
                            [ type_ "radio"
                            , class "form-check-input"
                            , name "mode"
                            , checked <| model.mode == Cumulative
                            , onCheck (always (SwitchMode Cumulative))
                            ]
                            []
                        , span [ class "ms-2" ] [ text "Cumulative" ]
                        ]
                    , label [ class "form-check-label" ]
                        [ input
                            [ type_ "radio"
                            , class "form-check-input"
                            , name "mode"
                            , checked <| model.mode == PerDay
                            , onCheck (always (SwitchMode PerDay))
                            ]
                            []
                        , span [ class "ms-2" ] [ text "Per-day" ]
                        ]
                    ]
                ]
            , viewEurope model
            , Event.countries allEvents
                |> Set.toList
                |> List.map (viewCountry model)
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
