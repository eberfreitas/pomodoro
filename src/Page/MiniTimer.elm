module Page.MiniTimer exposing (view)

import Color
import Css
import Html.Styled as Html
import Html.Styled.Attributes as Attributes
import Page.Settings as Settings
import Session
import Theme.Theme as Theme



-- MODEL


type alias Model a =
    { a
        | sessions : List Session.SessionDef
        , settings : Settings.Settings
        , active : Session.Active
    }



-- VIEW


view : Model a -> Html.Html msg
view { sessions, settings, active } =
    let
        totalRun =
            sessions |> Session.sessionsTotalRun |> toFloat
    in
    Html.ul
        [ Attributes.css
            [ Css.width <| Css.pct 100
            , Css.displayFlex
            , Css.padding <| Css.rem 0.25
            , Css.listStyle Css.none
            ]
        ]
        (sessions
            |> List.indexedMap
                (\index session ->
                    let
                        sizeInPct =
                            toFloat (Session.sessionSeconds session) * 100 / totalRun

                        backgroundColor =
                            session |> Session.toColor settings.theme

                        backgroundColor_ =
                            if index >= active.index then
                                backgroundColor |> Color.setAlpha 0.25

                            else
                                backgroundColor
                    in
                    Html.li
                        [ Attributes.css
                            [ Css.width <| Css.pct sizeInPct
                            , Css.height <| Css.rem 0.5
                            , Css.margin <| Css.rem 0.25
                            , Css.borderRadius <| Css.rem 0.25
                            , Css.backgroundColor <| Color.toCssColor backgroundColor_
                            , Css.overflow Css.hidden
                            ]
                        ]
                        [ if index == active.index then
                            let
                                elapsedPct =
                                    Session.elapsedPct active
                            in
                            Html.div
                                [ Attributes.css
                                    [ Css.width <| Css.pct elapsedPct
                                    , Css.height <| Css.pct 100
                                    , Css.backgroundColor <| Color.toCssColor backgroundColor
                                    ]
                                ]
                                []

                          else
                            Html.text ""
                        ]
                )
        )