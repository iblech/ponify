import Data.List
import Data.Maybe
import qualified Data.Text as T
import Data.Tuple
import Control.Applicative
import Options

ponify :: T.Text -> [(T.Text, T.Text)] -> T.Text
ponify input rules
  | null rules = input
  | otherwise  = ponify (uncurry replaceAll (head rules) input) (tail rules)

deponify :: T.Text -> [(T.Text, T.Text)] -> T.Text
deponify input rules = ponify input (map swap rules)

-- rules are just full text replaces with some extra glue
-- the markup of the rules file looks like this:
-- search :: replace
-- the word search gets replaced by replace

parseRules :: String -> [(T.Text, T.Text)]
parseRules = map (composeRule . words) . dropComments . lines
  where dropComments = filter (\x -> not (null x) && head x /= '#')
        composeRule list = mapTuple (T.pack . unwords) (take dotsIndex list, drop (dotsIndex + 1) list)
          where mapTuple f t = (f (fst t), f (snd t))
                dotsIndex = fromJust (elemIndex "::" list)

replaceAll  :: T.Text -> T.Text -> T.Text -> T.Text
replaceAll needle replace haystack = replaceMatches needle replace haystack matches
  where replaceMatches needle replace haystack matches
          | null matches = haystack
          | otherwise    = let replaceExpanded = if T.last replace == '*' then T.init replace else replace in
              replaceMatches needle replaceExpanded (T.take (fst (head matches)) haystack `T.append` replaceExpanded `T.append` (T.drop (snd (head matches)) haystack))
                (tail matches)
        matches = findMatches needle haystack

findMatches :: (Integral a, Num a) => T.Text -> T.Text -> [(a, a)]
findMatches pattern haystack = getIndices pattern haystack 0
  where getIndices :: (Integral a) => T.Text -> T.Text -> a -> [(a, a)]
        getIndices pattern haystack currentIndex
          | T.null haystack = []
          | match           = (currentIndex, matchLength) : getIndices pattern (T.tail haystack) (currentIndex + 1)
          | otherwise       = getIndices pattern (T.tail haystack) (currentIndex + 1)
            where match     = if T.last pattern == '*'
                              then
                                T.take ((T.length pattern) - 1) haystack == T.take ((T.length pattern) - 1) pattern
                              else 
                                let afterMatch = T.drop (T.length pattern) haystack in
                                  T.take (T.length pattern) haystack == pattern && (T.null afterMatch || (textElem (T.head afterMatch) (T.pack " \t\n\r")))
                  matchLength = if T.last pattern == '*'
                                then (fromIntegral (T.length pattern) - 1)
                                else (fromIntegral (T.length pattern))

textElem :: Char -> T.Text -> Bool
textElem c str = isJust (T.findIndex (== c) str)

-- onlyPunctuation str = T.foldl (\acc c -> c `elem` ".?!,\"\' " && acc) True str

data MainOptions = MainOptions
  {
    optPonify :: Bool,
    optDeponify :: Bool,
    optRules :: String
  }

instance Options MainOptions where
  defineOptions = pure MainOptions
    <*> simpleOption "ponify" True
      "Wether to ponify"
    <*> simpleOption "deponify" False
      "Wether to deponify"
    <*> simpleOption "rules" "rules"
      "Which rules file to use"

main :: IO ()
main = runCommand $ \opts args -> do
  -- get Stdin
  -- load rules
  contents <- getContents
  rules <- readFile (optRules opts)
  -- process the input
  let action = if (optDeponify opts) then deponify else ponify in
    putStr $ T.unpack $ action (T.pack contents) (parseRules rules)
