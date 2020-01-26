module Main exposing (..)

import Array
import Browser
import Html exposing (Html, br, button, div, span, table, td, text, tr)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Juralen.Cell exposing (Cell, Loc)
import Juralen.CellType exposing (CellType)
import Juralen.Grid exposing (Grid)
import Juralen.Player exposing (NewPlayer, Player)
import Juralen.PlayerColor exposing (PlayerColor)
import Juralen.Resources exposing (Resources)
import Juralen.Structure exposing (Structure)
import Juralen.Unit exposing (Unit)
import Juralen.UnitType exposing (UnitType)
import Random



---- MODEL ----


type alias Model =
    { nextId : Int
    , grid : Grid
    , selectedCell : Loc
    , players : List Player
    , activePlayer : Int
    , units : List Unit
    , init :
        { maxX : Int
        , maxY : Int
        , currentX : Int
        , currentY : Int
        , finished : Bool
        , newPlayers : List NewPlayer
        }
    }


init : ( Model, Cmd Msg )
init =
    update (RollNextCell { x = 0, y = 0 })
        { nextId = 1
        , grid = []
        , selectedCell = { x = 0, y = 0 }
        , players = []
        , activePlayer = 0
        , units = []
        , init =
            { maxX = 8
            , maxY = 8
            , currentX = 0
            , currentY = 0
            , finished = False
            , newPlayers =
                [ { name = "Lindsay", isHuman = True, color = Juralen.PlayerColor.Red }
                , { name = "Ilthanen Juralen", isHuman = True, color = Juralen.PlayerColor.Blue }
                , { name = "Velsyph", isHuman = True, color = Juralen.PlayerColor.Green }
                , { name = "Dakh", isHuman = True, color = Juralen.PlayerColor.Yellow }
                ]
            }
        }



---- FUNCTIONS ----


randomDefinedMax : Int -> Random.Generator Int
randomDefinedMax max =
    Random.int 0 max


type alias CurrentPlayerStats =
    { gold : String
    , actions : String
    , farms : String
    , towns : String
    , units : String
    }


currentPlayerStats : Model -> CurrentPlayerStats
currentPlayerStats model =
    { gold = String.fromInt (Juralen.Player.getResources model.players model.activePlayer).gold
    , actions = String.fromFloat (Juralen.Player.getResources model.players model.activePlayer).actions
    , farms = String.fromInt (Juralen.Grid.farmCountControlledBy model.grid model.activePlayer)
    , towns = String.fromInt (Juralen.Grid.townCountControlledBy model.grid model.activePlayer)
    , units = String.fromInt (List.length (List.filter (\unit -> unit.controlledBy == model.activePlayer) model.units))
    }



---- UPDATE ----


type Msg
    = GenerateNextCell Loc Int
    | RollNextCell Loc
    | GenerateNextPlayer (Maybe NewPlayer)
    | GenerateStartingLoc Player (List Player) Loc
    | RollStartingLocX Player (List Player)
    | RollStartingLocY Player (List Player) Int
    | MakeLocFromRolls Player (List Player) Int Int
    | DetermineFirstPlayer Int
    | StartTurn Player
    | SelectCell Loc
    | BuildUnit UnitType


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GenerateNextCell loc roll ->
            let
                nextX =
                    if model.init.currentY == model.init.maxY then
                        model.init.currentX + 1

                    else
                        model.init.currentX

                finished =
                    if model.init.currentX > model.init.maxX then
                        True

                    else
                        False

                nextY =
                    if model.init.currentY == model.init.maxY then
                        if finished == True then
                            model.init.currentY

                        else
                            0

                    else
                        model.init.currentY + 1

                prevInit =
                    model.init

                nextInit =
                    { prevInit | currentX = nextX, currentY = nextY, finished = finished }

                newGrid =
                    if finished == True then
                        model.grid

                    else if model.init.currentY == 0 then
                        model.grid ++ [ [ Juralen.Cell.generate loc roll ] ]

                    else
                        List.map
                            (\row ->
                                if List.length row > model.init.maxY then
                                    row

                                else
                                    row ++ [ Juralen.Cell.generate loc roll ]
                            )
                            model.grid

                newModel =
                    { model | init = nextInit, grid = newGrid }
            in
            update (RollNextCell { x = nextX, y = nextY }) newModel

        RollNextCell loc ->
            if model.init.finished == False then
                ( model, Random.generate (GenerateNextCell loc) (randomDefinedMax 101) )

            else if List.length model.init.newPlayers > 0 then
                update (GenerateNextPlayer (List.head model.init.newPlayers)) model

            else
                ( model, Cmd.none )

        GenerateNextPlayer potentialNewPlayer ->
            case potentialNewPlayer of
                Nothing ->
                    ( model, Cmd.none )

                Just newPlayer ->
                    let
                        nextId =
                            model.nextId + 1

                        player =
                            Juralen.Player.generate newPlayer model.nextId

                        players =
                            model.players ++ [ player ]

                        remainingNewPlayers : List NewPlayer
                        remainingNewPlayers =
                            case List.tail model.init.newPlayers of
                                Nothing ->
                                    []

                                Just remainingNewPlayerstail ->
                                    remainingNewPlayerstail

                        prevInit =
                            model.init

                        newInit =
                            { prevInit | newPlayers = remainingNewPlayers }

                        newModel =
                            { model | players = players, init = newInit, nextId = nextId }
                    in
                    if List.length remainingNewPlayers == 0 then
                        let
                            firstPlayer =
                                List.head newModel.players

                            otherPlayers =
                                case List.tail newModel.players of
                                    Nothing ->
                                        []

                                    Just otherPlayerList ->
                                        otherPlayerList
                        in
                        case firstPlayer of
                            Nothing ->
                                ( newModel, Cmd.none )

                            Just aPlayer ->
                                update (RollStartingLocX aPlayer otherPlayers) newModel

                    else
                        update (GenerateNextPlayer (List.head remainingNewPlayers)) newModel

        GenerateStartingLoc player nextPlayers loc ->
            let
                cell : Maybe Cell
                cell =
                    Juralen.Cell.validStartingCell model.grid loc
            in
            case cell of
                Nothing ->
                    update (RollStartingLocX player nextPlayers) model

                Just realCell ->
                    let
                        newGrid =
                            Juralen.Grid.replaceCell model.grid (Juralen.Cell.updateControl (Juralen.Cell.buildStructure realCell "todo") player)

                        nextPlayer =
                            List.head nextPlayers

                        remainingPlayers =
                            case List.tail nextPlayers of
                                Nothing ->
                                    []

                                Just playerList ->
                                    playerList

                        newUnits : List Unit
                        newUnits =
                            [ Juralen.Unit.buildUnit Juralen.UnitType.Soldier player.id loc model.nextId, Juralen.Unit.buildUnit Juralen.UnitType.Soldier player.id loc (model.nextId + 1), Juralen.Unit.buildUnit Juralen.UnitType.Soldier player.id loc (model.nextId + 2) ]

                        nextModel =
                            { model | grid = newGrid, units = model.units ++ newUnits, nextId = model.nextId + 3 }
                    in
                    case nextPlayer of
                        Nothing ->
                            ( nextModel, Random.generate DetermineFirstPlayer (randomDefinedMax (List.length model.players)) )

                        Just theNextPlayer ->
                            update (RollStartingLocX theNextPlayer remainingPlayers) nextModel

        RollStartingLocX player nextPlayers ->
            ( model, Random.generate (RollStartingLocY player nextPlayers) (randomDefinedMax 9) )

        RollStartingLocY player nextPlayers xVal ->
            ( model, Random.generate (MakeLocFromRolls player nextPlayers xVal) (randomDefinedMax 9) )

        MakeLocFromRolls player nextPlayers xVal yVal ->
            update (GenerateStartingLoc player nextPlayers { x = xVal, y = yVal }) model

        DetermineFirstPlayer roll ->
            let
                firstPlayer : Maybe Player
                firstPlayer =
                    Array.get roll (Array.fromList model.players)
            in
            case firstPlayer of
                Nothing ->
                    ( model, Random.generate DetermineFirstPlayer (randomDefinedMax (List.length model.players)) )

                Just player ->
                    update (StartTurn player) model

        StartTurn player ->
            ( { model | activePlayer = player.id }, Cmd.none )

        SelectCell loc ->
            ( { model | selectedCell = loc }, Cmd.none )

        BuildUnit unitType ->
            let
                newResources : Resources
                newResources =
                    Juralen.Resources.spend (Juralen.Player.getResources model.players model.activePlayer) (Juralen.UnitType.cost unitType)

                newUnit : Unit
                newUnit =
                    Juralen.Unit.buildUnit unitType model.activePlayer model.selectedCell model.nextId

                nextId : Int
                nextId =
                    model.nextId + 1

                newUnitList =
                    model.units ++ [ newUnit ]

                newPlayerList =
                    List.map
                        (\player ->
                            if player.id == model.activePlayer then
                                { player | resources = newResources }

                            else
                                player
                        )
                        model.players
            in
            if newResources.gold < 0 then
                ( model, Cmd.none )

            else
                ( { model | nextId = nextId, units = newUnitList, players = newPlayerList }, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div [ class "flex" ]
        [ table [ class "w-3/5" ]
            (List.map
                (\row ->
                    tr []
                        (List.map
                            (\cell ->
                                td []
                                    [ div
                                        [ class ("cell " ++ Juralen.Cell.getColorClass cell model.players)
                                        , style "border"
                                            (if cell.x == model.selectedCell.x && cell.y == model.selectedCell.y then
                                                "2px solid yellow"

                                             else
                                                ""
                                            )
                                        , onClick (SelectCell { x = cell.x, y = cell.y })
                                        ]
                                        [ text (Juralen.Structure.toString cell.structure)
                                        , br [] []
                                        , div [] (List.map (\unit -> span [ class "unit" ] [ text (Juralen.UnitType.short unit.unitType) ]) (Juralen.Unit.inCell model.units { x = cell.x, y = cell.y }))
                                        ]
                                    ]
                            )
                            row
                        )
                )
                model.grid
            )
        , div [ class "w-2/5 m-3" ]
            [ div [ class ("text-center p-3 " ++ Juralen.Player.getColorClass model.players (Just model.activePlayer)) ]
                [ text (Juralen.Player.getName model.players (Just model.activePlayer))
                , div [ class "flex" ]
                    [ div [ class "flex-1 p-2" ] [ text "Gold: ", text (currentPlayerStats model).gold ]
                    , div [ class "flex-1 p-2" ] [ text "Actions: ", text (currentPlayerStats model).actions ]
                    , div [ class "flex-1 p-2" ] [ text "Farms: ", text (currentPlayerStats model).farms ]
                    , div [ class "flex-1 p-2" ] [ text "Towns: ", text (currentPlayerStats model).towns ]
                    , div [ class "flex-1 p-2" ] [ text "Units: ", text (currentPlayerStats model).units ]
                    ]
                ]
            , div [ class "mt-4 border-2 rounded" ]
                [ div
                    [ class
                        ("p-3 "
                            ++ (case Juralen.Cell.find model.grid model.selectedCell of
                                    Nothing ->
                                        ""

                                    Just selectedCell ->
                                        Juralen.Cell.getColorClass selectedCell model.players
                               )
                        )
                    ]
                    [ text (String.fromInt model.selectedCell.x)
                    , text ", "
                    , text (String.fromInt model.selectedCell.y)
                    , br [] []
                    , div [ class "flex" ]
                        [ div [ class "flex-1" ]
                            [ text
                                (case Juralen.Cell.find model.grid model.selectedCell of
                                    Nothing ->
                                        ""

                                    Just selectedCell ->
                                        Juralen.CellType.toString selectedCell.cellType
                                )
                            ]
                        , div [ class "flex-1 italic" ]
                            [ text
                                (case Juralen.Cell.find model.grid model.selectedCell of
                                    Nothing ->
                                        "Not Controlled"

                                    Just selectedCell ->
                                        "("
                                            ++ (case selectedCell.controlledBy of
                                                    Nothing ->
                                                        "Not Controlled"

                                                    _ ->
                                                        Juralen.Player.getName model.players selectedCell.controlledBy
                                               )
                                            ++ ")"
                                )
                            ]
                        ]
                    ]
                ]
            , div []
                (List.map (\buildableUnit -> button [ class "build-unit", onClick (BuildUnit buildableUnit) ] [ text ("Build " ++ Juralen.UnitType.toString buildableUnit) ])
                    (case Juralen.Cell.find model.grid model.selectedCell of
                        Nothing ->
                            []

                        Just selectedCell ->
                            case selectedCell.controlledBy of
                                Nothing ->
                                    []

                                Just controlledBy ->
                                    if controlledBy /= model.activePlayer then
                                        []

                                    else
                                        Juralen.Structure.canBuild selectedCell.structure
                    )
                )
            , div [class "p-5"]
                (List.map (\unit -> 
                    div [class "flex p-2 bg-gray-700 my-2 rounded hover:bg-gray-600 text-white"] 
                        [ div [ class "w-2/3 text-left" ] [ text (Juralen.UnitType.toString unit.unitType) ]
                        , div [ class "flex-1" ] [ text "Atk: ", text (String.fromInt unit.attack) ]
                        , div [ class "flex-1" ] [ text "HP: ", text (String.fromInt unit.health) ]
                        , div [ class "flex-1" ] [ text "Moves: ", text (String.fromInt unit.movesLeft) ]
                        ]) (Juralen.Unit.inCell model.units model.selectedCell))
            ]
        ]



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
