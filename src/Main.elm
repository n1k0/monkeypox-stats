module Main exposing (main)

import Browser exposing (Document)
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


type alias Event =
    { date : Posix
    , country : String
    , newCases : Int
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


fromCountry : String -> List Event -> List Event
fromCountry country =
    List.filter (.country >> (==) country)


accumulate : List Event -> List ( Int, Event )
accumulate =
    List.foldl
        (\event acc ->
            ( event.newCases
                + (acc
                    |> List.head
                    |> Maybe.map Tuple.first
                    |> Maybe.withDefault 0
                  )
            , event
            )
                :: acc
        )
        []


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
    { title = "Monkeypox stats"
    , body =
        [ div [ class "container py-4" ]
            [ h1 [] [ text "Monkeypox stats" ]
            , model.events
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
                ]
            , pre []
                [ model.events
                    |> List.sortBy (.date >> Time.posixToMillis)
                    |> (case model.country of
                            Just c ->
                                fromCountry c

                            Nothing ->
                                identity
                       )
                    |> accumulate
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
