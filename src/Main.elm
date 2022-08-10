module Main exposing (main)

import Browser exposing (Document)
import Charts
import Dict exposing (Dict)
import Event exposing (Event)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Set exposing (Set)
import Time exposing (Posix)


type alias Model =
    { events : List Event
    , country : Maybe String
    , hovering : Dict String (List Charts.Hovered)
    }


type Msg
    = DataReceived (Result Http.Error (List Event))
    | OnHover String (List Charts.Hovered)
    | SwitchCountry (Maybe String)


init : () -> ( Model, Cmd Msg )
init _ =
    ( { events = []
      , country = Nothing
      , hovering = Dict.fromList []
      }
    , Http.get
        { url = dataUrl
        , expect = Http.expectJson DataReceived (Decode.list decodeEvents)
        }
    )


dataUrl : String
dataUrl =
    "https://opendata.ecdc.europa.eu/monkeypox/casedistribution/json/data.json"


countries : List Event -> Set String
countries =
    List.map .country >> Set.fromList


decodeEvents : Decoder Event
decodeEvents =
    Decode.map3 Event
        (Decode.field "DateRep" Iso8601.decoder)
        (Decode.field "CountryExp" Decode.string)
        (Decode.field "ConfCases" Decode.int)


formatDate : Posix -> String
formatDate =
    Iso8601.fromTime
        >> String.dropRight 14


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

        SwitchCountry country ->
            ( { model | country = country }, Cmd.none )


viewCountry : Model -> String -> Html Msg
viewCountry { hovering, events } country =
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
                                [ text <| String.fromInt tot ++ " tot. on " ++ formatDate date ]

                        Nothing ->
                            text ""
                    ]
                ]
            , div [ class "card-body p-2" ]
                [ countryEvents
                    |> Event.accumulate
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


view : Model -> Document Msg
view model =
    let
        allEvents =
            model.events
                |> List.sortBy (.date >> Time.posixToMillis)

        selectedEvents =
            case model.country of
                Just c ->
                    allEvents |> Event.fromCountry c

                Nothing ->
                    allEvents
    in
    { title = "Monkeypox stats"
    , body =
        [ div [ class "container py-4" ]
            [ h1 [] [ text "Monkeypox stats for EU" ]
            , case Event.total allEvents of
                Just ( date, tot ) ->
                    p [ class "text-muted fw-bold" ]
                        [ text <| String.fromInt tot ++ " total confirmed cases as of " ++ formatDate date ++ " in Europe" ]

                Nothing ->
                    text ""
            , allEvents
                |> countries
                |> Set.toList
                |> List.map (viewCountry model)
                |> div [ class "row row-cols-1 row-cols-sm-2 row-cols-lg-3 g-4" ]
            , selectedEvents
                |> Event.accumulate
                |> Charts.view
                    { hovering = model.hovering |> Dict.get "" |> Maybe.withDefault []
                    , onHover = OnHover ""
                    , pointLabel = "Confirmed cases"
                    , width = 450 * 3
                    , height = 280 * 3
                    }
            , p []
                [ a [ href "https://www.ecdc.europa.eu/en/publications-data/data-monkeypox-cases-eueea" ]
                    [ text "Data source" ]
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
