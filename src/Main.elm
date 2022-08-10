module Main exposing (main)

import Browser exposing (Document)
import Charts
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
    }


type Msg
    = DataReceived (Result Http.Error (List Event))
    | SwitchCountry (Maybe String)


init : () -> ( Model, Cmd Msg )
init _ =
    ( { events = [], country = Nothing }
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

        SwitchCountry country ->
            ( { model | country = country }, Cmd.none )


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
            [ h1 [] [ text "Monkeypox stats" ]
            , case Event.total allEvents of
                Just ( date, tot ) ->
                    p [ class "text-muted fw-bold" ]
                        [ text <| String.fromInt tot ++ " confirmed cases as of " ++ formatDate date ++ " in Europe" ]

                Nothing ->
                    text ""
            , allEvents
                |> countries
                |> Set.toList
                |> (::) ""
                |> List.map
                    (\c ->
                        option [ value c, selected <| model.country == Just c ]
                            [ text <|
                                if c == "" then
                                    "All countries"

                                else
                                    c
                            ]
                    )
                |> select
                    [ class "form-select"
                    , onInput
                        (\s ->
                            SwitchCountry
                                (case s of
                                    "" ->
                                        Nothing

                                    c ->
                                        Just c
                                )
                        )
                    ]
            , h2 []
                [ model.country
                    |> Maybe.withDefault "Tous les pays"
                    |> text
                , case Event.total selectedEvents of
                    Just ( date, tot ) ->
                        small [ class "text-muted fs-5 ms-2" ]
                            [ text <| String.fromInt tot ++ " confirmed cases as of " ++ formatDate date ]

                    Nothing ->
                        text ""
                ]
            , selectedEvents
                |> Event.accumulate
                |> List.map (\( tot, { date } ) -> { date = date, total = tot })
                |> Charts.view

            -- , Charts.view2
            , pre []
                [ selectedEvents
                    |> Event.accumulate
                    |> Debug.toString
                    |> String.replace "),(" "),\n("
                    |> text
                ]
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
