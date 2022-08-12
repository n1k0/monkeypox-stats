module Main exposing (main)

import Browser exposing (Document)
import Charts
import Dict exposing (Dict)
import Event exposing (Event)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import RemoteData exposing (WebData)
import Set
import Time


type alias Model =
    { mode : Mode
    , events : WebData (List Event)
    , hovering : Dict String (List Charts.Hovered)
    }


type Msg
    = DataReceived (WebData (List Event))
    | OnHover String (List Charts.Hovered)
    | SwitchMode Mode


type Mode
    = Cumulative
    | PerDay
    | SevenDaysAverage


init : () -> ( Model, Cmd Msg )
init _ =
    ( { mode = Cumulative
      , events = RemoteData.Loading
      , hovering = Dict.fromList []
      }
    , Http.get
        { url = dataUrl
        , expect =
            Event.decodeList
                |> Http.expectJson (RemoteData.fromResult >> DataReceived)
        }
    )


dataUrl : String
dataUrl =
    "https://opendata.ecdc.europa.eu/monkeypox/casedistribution/json/data.json"


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DataReceived events ->
            ( { model | events = events }, Cmd.none )

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
        [ div [ class "card-header d-flex flex-column flex-sm-row justify-content-between gap-2" ]
            [ span [] [ country |> Maybe.withDefault "Europe" |> text ]
            , span []
                [ case Event.total selectedEvents of
                    Just ( date, tot ) ->
                        [ strong [] [ text (String.fromFloat tot) ]
                        , text "total confirmed cases on"
                        , text (Event.formatDate date)
                        ]
                            |> List.intersperse (text " ")
                            |> small [ class "text-muted" ]

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
                |> Charts.line
                    { hovering = hovering |> Dict.get countryId |> Maybe.withDefault []
                    , onHover = OnHover countryId
                    , width = width
                    , height = height
                    }
            ]
        ]


viewEvents : Model -> List Event -> List (Html Msg)
viewEvents model events =
    let
        allEvents =
            events
                |> List.sortBy (.date >> Time.posixToMillis)
    in
    [ div [ class "row align-items-end my-3" ]
        [ div [ class "col-md-6 col-lg-7 my-2" ]
            [ case Event.total allEvents of
                Just ( date, tot ) ->
                    div [ class "text-muted fw-bold" ]
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
                    label [ class "form-check-label text-nowrap" ]
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
            |> div [ class "col-md-6 col-lg-5 my-2 d-flex justify-content-center justify-content-md-end gap-4" ]
        ]
    , viewCard
        { country = Nothing
        , events = allEvents
        , mode = model.mode
        , hovering = model.hovering
        , width = 480 * 3
        , height = 280 * 1.5
        }
    , Event.countries allEvents
        |> Set.toList
        |> List.map
            (\country ->
                div [ class "col" ]
                    [ viewCard
                        { country = Just country
                        , events = allEvents
                        , mode = model.mode
                        , hovering = model.hovering
                        , width = 450
                        , height = 280
                        }
                    ]
            )
        |> div [ class "row row-cols-1 row-cols-sm-2 row-cols-lg-3 g-4 my-3" ]
    , div [ class "my-3" ]
        [ allEvents
            |> Event.sumByCountry
            |> Charts.bars
                { width = 480 * 3
                , height = 280 * 1.8
                }
        ]
    ]


view : Model -> Document Msg
view model =
    { title = "Monkeypox stats EU"
    , body =
        [ div [ class "container py-4" ]
            [ h1 [ class "mb-3" ] [ text "Monkeypox stats for EU" ]
            , main_ [ class "my-3" ]
                (case model.events of
                    RemoteData.NotAsked ->
                        []

                    RemoteData.Loading ->
                        [ div
                            [ class "d-flex flex-column gap-3 justify-content-center align-items-center"
                            , style "min-height" "350px"
                            ]
                            [ div [ class "spinner-border text-primary", attribute "role" "status" ] []
                            , p [ class "text-muted" ] [ text "Loading…" ]
                            ]
                        ]

                    RemoteData.Failure error ->
                        [ div [ class "alert alert-info" ]
                            [ text <| errorToString error ]
                        ]

                    RemoteData.Success events ->
                        viewEvents model events
                )
            , footer [ class "d-flex justify-content-center gap-5 mt-3" ]
                [ a [ href "https://www.ecdc.europa.eu/en/publications-data/data-monkeypox-cases-eueea" ]
                    [ text "Data source" ]
                , a [ href "https://github.com/n1k0/monkeypox-stats" ] [ text "Source code" ]
                , a [ href "https://nicolas.perriault.net" ] [ text "Author" ]
                ]
            ]
        ]
    }


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Http.Timeout ->
            "Unable to reach the server, try again"

        Http.NetworkError ->
            "Unable to reach the server, check your network connection"

        Http.BadStatus 500 ->
            "The server had a problem, try again later"

        Http.BadStatus 400 ->
            "Verify your information and try again"

        Http.BadStatus _ ->
            "Unknown error"

        Http.BadBody errorMessage ->
            errorMessage


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view = view
        , subscriptions = always Sub.none
        }
