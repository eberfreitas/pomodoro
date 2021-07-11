module View.Stats exposing (render)

import Calendar
import Colors
import Css
import Date exposing (Date, Unit(..))
import Helpers
import Html.Styled as Html exposing (Html)
import Html.Styled.Attributes as HtmlAttr
import Html.Styled.Events as Event
import Html.Styled.Keyed as Keyed
import List.Extra as ListEx
import Model exposing (Model)
import Msg exposing (Msg(..))
import Themes.Theme as Theme
import Themes.Types exposing (Theme)
import Time exposing (Zone)
import Tuple.Trio as Trio
import Types exposing (Cycle, Page(..), StatState(..), StatsDef)
import View.Common as Common
import View.MiniTimer as MiniTimer


render : Model -> Html Msg
render ({ settings } as model) =
    Html.div []
        [ MiniTimer.render model
        , Html.div
            [ HtmlAttr.css
                [ Css.margin2 (Css.rem 2) Css.auto
                , Css.maxWidth <| Css.px 520
                ]
            ]
            [ Common.h1 settings.theme "Statistics"
            , case model.page of
                StatsPage (Loaded def) ->
                    renderLoaded model.zone settings.theme def

                _ ->
                    Html.text ""
            ]
        ]


renderLoaded : Zone -> Theme -> StatsDef -> Html Msg
renderLoaded zone theme def =
    Html.div []
        [ renderCalendar zone theme def.monthly def.navDate def.logDate
        , renderHourlyAverages zone theme def.monthly
        , renderDailyLogs zone theme def.logDate def.daily
        ]


renderHourlyAverages : Zone -> Theme -> List Cycle -> Html msg
renderHourlyAverages zone theme log =
    let
        averages =
            hourlyAverages zone log

        hours =
            List.range 0 23

        inMinutes x =
            x // 60
    in
    Html.div [ HtmlAttr.css [ Css.marginBottom <| Css.rem 2 ] ]
        [ Common.h2 theme "Most productive hours" [ HtmlAttr.css [ Css.marginBottom <| Css.rem 2 ] ] []
        , hours
            |> List.map
                (\h ->
                    averages
                        |> ListEx.find (Trio.first >> (==) h)
                        |> Maybe.map
                            (\( _, secs, pct ) ->
                                Html.div
                                    [ HtmlAttr.css
                                        [ Css.width <| Css.pct 4.16666
                                        , Css.height <| Css.pct pct
                                        , Css.backgroundColor (theme |> Theme.longBreakColor |> Colors.toCssColor)
                                        , Css.margin2 Css.zero (Css.rem 0.25)
                                        ]
                                    , HtmlAttr.title (inMinutes secs |> String.fromInt)
                                    ]
                                    []
                            )
                        |> Maybe.withDefault
                            (Html.div
                                [ HtmlAttr.css
                                    [ Css.width <| Css.pct 4.16666
                                    , Css.margin2 Css.zero (Css.rem 0.25)
                                    ]
                                ]
                                [ Html.text "" ]
                            )
                )
            |> Html.div
                [ HtmlAttr.css
                    [ Css.displayFlex
                    , Css.alignItems Css.flexEnd
                    , Css.height <| Css.rem 5
                    , Css.width <| Css.pct 100
                    ]
                ]
        , Html.div
            [ HtmlAttr.css
                [ Css.borderTop <| Css.px 1
                , Css.borderStyle Css.solid
                , Css.borderRight Css.zero
                , Css.borderBottom Css.zero
                , Css.borderLeft Css.zero
                , Css.paddingTop <| Css.rem 0.35
                , Css.fontSize <| Css.rem 0.5
                , Css.color (theme |> Theme.textColor |> Colors.toCssColor)
                ]
            ]
            (hours
                |> List.map
                    (\h ->
                        Html.div
                            [ HtmlAttr.css
                                [ Css.width <| Css.pct 4.16666
                                , Css.margin2 Css.zero (Css.rem 0.25)
                                , Css.textAlign Css.center
                                ]
                            ]
                            [ Html.text (h |> String.fromInt |> String.padLeft 2 '0') ]
                    )
                |> Html.div
                    [ HtmlAttr.css
                        [ Css.displayFlex
                        , Css.width <| Css.pct 100
                        ]
                    ]
                |> List.singleton
            )
        ]


renderDailyLogs : Zone -> Theme -> Date -> List Cycle -> Html Msg
renderDailyLogs zone theme selected log =
    let
        formatToHour t =
            ( t, t )
                |> Tuple.mapBoth
                    (Time.toHour zone >> String.fromInt >> String.padLeft 2 '0')
                    (Time.toMinute zone >> String.fromInt >> String.padLeft 2 'o')
                |> (\( h, m ) -> h ++ ":" ++ m)

        renderCycle interval start end seconds =
            let
                innerPct =
                    interval
                        |> Model.intervalSeconds
                        |> (\t -> 100 * seconds // t)
                        |> String.fromInt

                intervalColor =
                    interval |> Theme.intervalColor theme

                dimmed =
                    intervalColor |> Colors.setAlpha 0.5 |> Colors.toRgbaString

                full =
                    intervalColor |> Colors.toRgbaString
            in
            Html.div
                [ HtmlAttr.css
                    [ Css.padding <| Css.rem 0.5
                    , Css.position Css.relative
                    , Css.margin2 (Css.rem 0.5) Css.zero
                    , Css.color (theme |> Theme.contrastColor |> Colors.toCssColor)
                    , Css.lineHeight <| Css.rem 1
                    , Css.property "background-image"
                        ("linear-gradient(to right, "
                            ++ full
                            ++ ", "
                            ++ full
                            ++ " "
                            ++ innerPct
                            ++ "%, "
                            ++ dimmed
                            ++ " "
                            ++ innerPct
                            ++ "%, "
                            ++ dimmed
                            ++ " 100%)"
                        )
                    ]
                ]
                [ Html.div [] [ Html.text (formatToHour start ++ " ➞ " ++ formatToHour end) ] ]
    in
    Html.div [ HtmlAttr.css [ Css.color (theme |> Theme.textColor |> Colors.toCssColor) ] ]
        [ Common.h2 theme
            (selected |> Date.format "y-MM-d")
            [ HtmlAttr.css [ Css.marginBottom <| Css.rem 2 ] ]
            []
        , Html.div []
            [ case log of
                [] ->
                    Html.div
                        [ HtmlAttr.css [ Css.textAlign Css.center ] ]
                        [ Html.text "No logs" ]

                log_ ->
                    log_
                        |> List.sortBy (.start >> Maybe.map Time.posixToMillis >> Maybe.withDefault 0)
                        |> List.filterMap
                            (\{ interval, start, end, seconds } ->
                                case ( start, end, seconds ) of
                                    ( Just s, Just e, Just sc ) ->
                                        Just <| ( s |> Time.posixToMillis |> String.fromInt, renderCycle interval s e sc )

                                    _ ->
                                        Nothing
                            )
                        |> Keyed.node "div" []
            ]
        ]


hourlyAverages : Zone -> List Cycle -> List ( Int, Int, Float )
hourlyAverages zone log =
    let
        aggregate agg { start, seconds } =
            let
                hour =
                    start |> Time.toHour zone
            in
            case agg |> ListEx.findIndex (Trio.first >> (==) hour) of
                Just idx ->
                    agg |> ListEx.updateAt idx (\( h, count, secs ) -> ( h, count + 1, secs + seconds ))

                Nothing ->
                    ( hour, 1, seconds ) :: agg

        firstPass =
            log
                |> List.filter (.interval >> Model.intervalIsActivity)
                |> List.foldl
                    (\cycle agg ->
                        cycle
                            |> Model.cycleMaterialized
                            |> Maybe.map (aggregate agg)
                            |> Maybe.withDefault agg
                    )
                    []
                |> List.map (\( h, count, secs ) -> ( h, secs // count ))

        max =
            firstPass |> ListEx.maximumBy Tuple.second |> Maybe.map Tuple.second |> Maybe.withDefault 0
    in
    firstPass |> List.map (\( h, secs ) -> ( h, secs, toFloat secs * 100 / toFloat max ))


monthlyAverages : Zone -> List Cycle -> List ( Date, Float )
monthlyAverages zone log =
    let
        aggregate agg { start, seconds } =
            let
                date =
                    start |> Date.fromPosix zone
            in
            case agg |> ListEx.findIndex (Tuple.first >> (==) date) of
                Just idx ->
                    agg |> ListEx.updateAt idx (\( d, s ) -> ( d, s + seconds ))

                Nothing ->
                    ( date, seconds ) :: agg

        firstPass =
            log
                |> List.filter (.interval >> Model.intervalIsActivity)
                |> List.foldl
                    (\cycle agg ->
                        cycle
                            |> Model.cycleMaterialized
                            |> Maybe.map (aggregate agg)
                            |> Maybe.withDefault agg
                    )
                    []

        max =
            firstPass |> ListEx.maximumBy Tuple.second |> Maybe.map Tuple.second |> Maybe.withDefault 0
    in
    firstPass |> List.map (\( date, seconds ) -> ( date, (toFloat seconds * 100) / toFloat max ))


renderCalendar : Zone -> Theme -> List Cycle -> Date -> Date -> Html Msg
renderCalendar zone theme monthly navDate logDate =
    let
        averages =
            monthlyAverages zone monthly

        cellStyle =
            Css.batch
                [ Css.displayFlex
                , Css.alignItems Css.center
                , Css.justifyContent Css.center
                , Css.height <| Css.rem 2.3
                ]

        averageForTheDay day =
            averages
                |> ListEx.find (Tuple.first >> (==) day)
                |> Maybe.map Tuple.second
                |> Maybe.withDefault 0
                |> Helpers.flip (/) 100

        cellBgColor average =
            average
                |> Helpers.flip Colors.setAlpha (theme |> Theme.foregroundColor)
                |> Colors.toCssColor

        cellTextColor average =
            if average < 0.5 then
                theme |> Theme.textColor |> Colors.toCssColor

            else
                theme |> Theme.contrastColor |> Colors.toCssColor

        cellBorder day =
            if day == logDate then
                Css.border3 (Css.rem 0.25) Css.solid (theme |> Theme.longBreakColor |> Colors.toCssColor)

            else
                Css.borderStyle Css.none

        buildDay _ day =
            let
                average =
                    averageForTheDay day.date

                style =
                    Css.batch
                        [ Css.display Css.block
                        , Css.width <| Css.pct 100
                        , Css.height <| Css.pct 100
                        , Css.backgroundColor (cellBgColor average)
                        , Css.fontSize <| Css.rem 0.75
                        , Css.boxSizing Css.borderBox
                        , Css.color (cellTextColor average)
                        ]

                renderFn d =
                    if d.dayDisplay == "  " then
                        Html.div [ HtmlAttr.css [ style ] ]

                    else
                        Html.button
                            [ HtmlAttr.css [ style, Css.cursor Css.pointer, cellBorder d.date ]
                            , Event.onClick (ChangeLogDate d.date)
                            ]
            in
            Html.div
                [ HtmlAttr.css [ cellStyle ] ]
                [ renderFn day [ Html.text day.dayDisplay ] ]

        calendar =
            navDate
                |> Calendar.fromDate Nothing
                |> List.concat
                |> List.map (buildDay logDate)

        arrowStyle =
            Css.batch
                [ Css.width <| Css.rem 1.5
                , Css.height <| Css.rem 1.5
                , Css.borderStyle Css.none
                , Css.backgroundColor Css.transparent
                , Css.cursor Css.pointer
                , Css.color (theme |> Theme.textColor |> Colors.toCssColor)
                ]

        arrow date float icon =
            Html.button
                [ HtmlAttr.css [ arrowStyle, Css.float float ]
                , Event.onClick <| ChangeNavDate date
                ]
                [ Common.icon icon ]

        prevMonth =
            navDate |> Date.add Months -1

        nextMonth =
            navDate |> Date.add Months 1
    in
    Html.div
        [ HtmlAttr.css
            [ Css.margin2 (Css.rem 2) Css.auto
            , Css.maxWidth <| Css.px 280
            ]
        ]
        [ Html.div
            [ HtmlAttr.css [ Css.position Css.relative, Css.marginBottom <| Css.rem 1 ] ]
            [ Common.h2 theme
                (navDate |> Date.format "MMM / y")
                []
                [ arrow prevMonth Css.left "chevron_left"
                , arrow nextMonth Css.right "chevron_right"
                ]
            ]
        , Html.div
            [ HtmlAttr.css
                [ Css.property "display" "grid"
                , Css.property "grid-template-columns" "repeat(7, 1fr)"
                , Css.property "column-gap" ".2rem"
                , Css.property "row-gap" ".2rem"
                ]
            ]
            ([ "S", "M", "T", "W", "T", "F", "S" ]
                |> List.map
                    (\wd ->
                        Html.div
                            [ HtmlAttr.css [ cellStyle, Css.fontWeight Css.bold ] ]
                            [ Html.div [] [ Html.text wd ] ]
                    )
                |> Helpers.flip (++) calendar
            )
        ]
