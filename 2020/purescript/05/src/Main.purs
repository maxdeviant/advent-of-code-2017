module Main where

import Prelude
import Data.Array (last, slice, sort, uncons, (..))
import Data.Array as Array
import Data.Either (Either(..), note)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype, unwrap)
import Data.String.CodeUnits (splitAt, toCharArray)
import Data.String.Utils (lines)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Console (log, logShow)
import Node.Encoding (Encoding(..))
import Node.FS.Sync (readTextFile)

data Half
  = Upper
  | Lower

class Halvable a where
  half :: a -> Half

data RowSpecifier
  = FrontRow
  | BackRow

instance halvableRowSpecifier :: Halvable RowSpecifier where
  half FrontRow = Lower
  half BackRow = Upper

data ColumnSpecifier
  = LeftColumn
  | RightColumn

instance halvableColumnSpecifier :: Halvable ColumnSpecifier where
  half LeftColumn = Lower
  half RightColumn = Upper

newtype BoardingPass
  = BoardingPass { row :: Array RowSpecifier, column :: Array ColumnSpecifier }

type Seat
  = { row :: Int, column :: Int }

partition :: forall a. Halvable a => Array Int -> Array a -> Maybe Int
partition space halves = case uncons halves of
  Just { head, tail } -> case half head of
    Upper -> partition (space # slice midpoint (Array.length space)) tail
    Lower -> partition (space # slice 0 midpoint) tail
  Nothing -> Array.head space
  where
  midpoint = Array.length space / 2

parseBoardingPass :: String -> Either String BoardingPass
parseBoardingPass input = do
  let
    { before: rowSpecifier, after: columnSpecifier } = input # splitAt 7
  row <-
    rowSpecifier
      # toCharArray
      # traverse
          ( \char -> case char of
              'F' -> pure FrontRow
              'B' -> pure BackRow
              invalidChar -> Left $ "Invalid row specifier: " <> show invalidChar
          )
  column <-
    columnSpecifier
      # toCharArray
      # traverse
          ( \char -> case char of
              'L' -> pure LeftColumn
              'R' -> pure RightColumn
              invalidChar -> Left $ "Invalid column specifier: " <> show invalidChar
          )
  pure $ BoardingPass { row, column }

findSeat :: BoardingPass -> Either String Seat
findSeat (BoardingPass boardingPass) = do
  row <- partition (0 .. 127) boardingPass.row # note "Row not found."
  column <- partition (0 .. 7) boardingPass.column # note "Column not found."
  pure { row, column }

newtype SeatId
  = SeatId Int

derive instance newtypeSeatId :: Newtype SeatId _

derive instance eqSeatId :: Eq SeatId

derive instance ordSeatId :: Ord SeatId

seatId :: Seat -> SeatId
seatId { row, column } = SeatId $ row * 8 + column

partOne :: String -> Either String Int
partOne input = do
  seats <-
    input
      # lines
      # traverse (parseBoardingPass >=> findSeat)
  seats
    # map seatId
    # sort
    # last
    # map unwrap
    # note ("No highest seat ID found.")

findMySeat :: Array SeatId -> Either String SeatId
findMySeat seats = do
  let
    sortedSeats = sort seats
  firstSeat <- Array.head sortedSeats # map unwrap # note "First seat not found."
  lastSeat <- Array.last sortedSeats # map unwrap # note "Last seat not found."
  let
    allSeats = firstSeat .. lastSeat # map SeatId
  let
    missingSeats = Array.difference allSeats seats
  case missingSeats of
    [ mySeat ] -> pure mySeat
    [] -> Left "No missing seats."
    _ -> Left $ "More than one missing seat: " <> show (map unwrap missingSeats)

partTwo :: String -> Either String Int
partTwo input = do
  seats <-
    input
      # lines
      # traverse (parseBoardingPass >=> findSeat)
  seats
    # map seatId
    # findMySeat
    # map unwrap

main :: Effect Unit
main = do
  input <- readTextFile UTF8 "input.txt"
  log "Part One"
  case partOne input of
    Right answer -> logShow answer
    Left error -> log $ "Failed with: " <> error
  log "Part Two"
  case partTwo input of
    Right answer -> logShow answer
    Left error -> log $ "Failed with: " <> error
