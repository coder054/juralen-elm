module Juralen.Cell exposing (..)

import Juralen.Player exposing (Player)
import Juralen.Structure exposing (Structure)
import Juralen.UnitType exposing (UnitType)
import Juralen.CellType exposing (CellType)


type alias Loc =
    { x : Int
    , y : Int
    }


type alias Cell =
    { cellType : CellType
    , controlledBy : Maybe Int
    , defBonus : Int
    , structure : Maybe Structure
    , x : Int
    , y : Int
    }


generate : Loc -> Int -> Cell
generate loc roll =
    if roll <= 12 then
        { cellType = Juralen.CellType.Plains
        , controlledBy = Nothing
        , defBonus = 3
        , structure = Just Juralen.Structure.Town
        , x = loc.x
        , y = loc.y
        }

    else if roll > 12 && roll <= 20 then
        { cellType = Juralen.CellType.Mountain
        , controlledBy = Nothing
        , defBonus = 0
        , structure = Nothing
        , x = loc.x
        , y = loc.y
        }

    else if roll > 20 && roll <= 40 then
        { cellType = Juralen.CellType.Forest
        , controlledBy = Nothing
        , defBonus = 1
        , structure = Nothing
        , x = loc.x
        , y = loc.y
        }

    else
        { cellType = Juralen.CellType.Plains
        , controlledBy = Nothing
        , defBonus = 0
        , structure = Nothing
        , x = loc.x
        , y = loc.y
        }


find : List (List Cell) -> Loc -> Maybe Cell
find grid loc =
    Maybe.andThen (\row -> List.head (List.filter (\innerCell -> innerCell.x == loc.x && innerCell.y == loc.y) row)) (List.head (List.filter (\row -> List.length (List.filter (\innerCell -> innerCell.x == loc.x && innerCell.y == loc.y) row) > 0) grid))

validStartingCell : List (List Cell) -> Loc -> Maybe Cell
validStartingCell grid loc =
    Maybe.andThen (\row -> List.head (List.filter (\innerCell -> innerCell.x == loc.x && innerCell.y == loc.y) row)) (List.head (List.filter (\row -> List.length (List.filter (\innerCell -> innerCell.x == loc.x && innerCell.y == loc.y && hasStructure innerCell == False) row) > 0) grid))

hasStructure : Cell -> Bool
hasStructure cell =
    case cell.structure of
        Nothing ->
            False

        _ ->
            True


buildStructure : Cell -> String -> Cell
buildStructure cell structureName =
    { cell | structure = Just Juralen.Structure.Citadel, cellType = Juralen.CellType.Plains, defBonus = 7 }


updateControl : Cell -> Player -> Cell
updateControl cell player =
    { cell | controlledBy = Just player.id }


getColorClass : Cell -> List Player -> String
getColorClass cell players =
    case cell.controlledBy of
        Nothing ->
            Juralen.CellType.getColorClass cell.cellType

        _ ->
            Juralen.Player.getColorClass players cell.controlledBy