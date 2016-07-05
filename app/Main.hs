module Main where

import Lib
import Control.Monad
import Data.Text (unpack, split, pack)
import System.Console.Haskeline
import Data.List (maximumBy)
import Data.Ord (comparing)
import System.Random (getStdGen, randomR)
import System.Exit (exitSuccess)
import Control.Applicative ((<$>))
import Data.Maybe (maybe)

outputBoard :: Board -> IO ()
outputBoard b = (putStrLn . unpack $ drawBoard b) >> putStrLn "\n"

getInput :: (Int -> Int -> Piece) -> IO Piece
getInput piece = do
  line <- runInputT defaultSettings $ getInputLine "Your move: "
  return $ processLn line
  where
    processLn Nothing   = undefined
    processLn (Just ln) = mkPiece
                        . map (read . unpack)
                        . split (== ',')
                        $ pack ln
    mkPiece [x, y] = piece x y

opponentMove :: Bool -> Board -> Board
opponentMove isX brd = addPiece (snd $ minimax brd Maximize isX) brd

opponentMoveAB :: Bool -> Board -> Board
opponentMoveAB isX brd = addPiece move brd
  where
    (s, move) = alphaBeta brd Maximize isX (minBound :: Int) (maxBound :: Int)

initGame :: IO Players
initGame = do
  x   <- fmap (maybe True (== 'y')) $ runInputT defaultSettings
                                    $ getInputChar "X? (y/n): "
  num <- fmap (fst . choice) getStdGen
  let (me, ai) = (makePlayer x False, makePlayer (not x) True)
    in case num of
        1 -> putStrLn "You go first"  >> return (me, ai)
        2 -> putStrLn "You go second" >> return (ai, me)
  where choice      = randomR (1 :: Int, 2)
        makePlayer bEx ai
          | bEx       = Player { isX = bEx, isAI = ai, decision = allXs }
          | otherwise = Player { isX = bEx, isAI = ai, decision = allOs }

main :: IO ()
main = do
  (p1, p2) <- initGame
  gameLoop emptyBoard p1 p2
  where
    gameLoop board p1@Player{isX = x, decision = decision, isAI = ai} p2 = do
      outputBoard board
      if ai
        then runAI     x ai decision board p1 p2
        else runPlayer x ai decision board p1 p2

    runAI x ai decision board p1 p2 =
      let nextBoard = opponentMoveAB x board
        in do
          displayStatus ai decision nextBoard
          gameLoop nextBoard p2 p1

    runPlayer x ai decision board p1 p2= do
      nextBoard <- getNextBoard x board
      displayStatus ai decision nextBoard
      gameLoop nextBoard p2 p1

    displayStatus isAI decision board
      | isAI && gameDone     = putStrLn "Defeat!"  >> finish
      | not isAI && gameDone = putStrLn "Victory!" >> finish
      | null $ moves board   = putStrLn "Draw!"    >> finish
      | otherwise            = return ()
      where gameDone = victory board decision

    finish = exitSuccess

    getNextBoard isX board
      | isX       = (`addPiece` board) <$> getInput X
      | otherwise = (`addPiece` board) <$> getInput O
