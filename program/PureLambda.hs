module PureLambda where

import Text.Parsec
import qualified Text.Parsec.Token as T
import Text.Parsec.Language (emptyDef)
import Text.Parsec.String (Parser)
import Data.List (union, delete)

type Ide = String
data Term = Var Ide | App Term Term | Abs Ide Term deriving Eq

absOpr = "."
absHead = "\\"
appOpr = " "

-- Grammar is:
-- var = letter, { letter | digit | "_" };
-- term = chain_term, {chain_term};
-- chain_term = var
--           | "(", term, ")"
--           | "\", var, ".", term;


-- Lexer
lexer :: T.TokenParser ()
lexer = T.makeTokenParser emptyDef

whiteSpace = T.whiteSpace lexer
lexeme     = T.lexeme lexer
symbol     = T.symbol lexer
parens     = T.parens lexer
identifier = T.identifier lexer

-- Parser
varParser :: Parser Term
varParser = do
  var <- identifier;
  return $ Var var

termParser :: Parser Term
termParser = do
  ls <- many1 chainTermParser
  return $ foldl1 App ls

chainTermParser :: Parser Term
chainTermParser = varParser <|> (parens termParser) <|>
                  do
                    lexeme $ symbol "\\"
                    m <- lexeme identifier
                    lexeme $ symbol "."
                    t <- lexeme termParser
                    return $ Abs m t

lambdaParser :: Parser Term
lambdaParser = do
  whiteSpace
  termParser

fullForm :: Term -> String
fullForm (Var x) = x
fullForm (Abs x (Var y)) = absHead ++ x ++ absOpr ++ y
fullForm (Abs x y) = absHead ++ x ++ absOpr ++ "(" ++ fullForm y ++ ")"
fullForm (App x y) = helper x ++ appOpr ++ helper y
  where helper (Var a) = a
        helper a = "(" ++ fullForm a ++ ")"

parseFull :: Parser Term -> String -> IO ()
parseFull p = helper . runParser p () ""
  where helper (Left err) = do putStr "parse error at "
                               print err
        helper (Right x)  = putStrLn $ fullForm x

parseLambda :: String -> Term
parseLambda = helper . runParser lambdaParser () ""
  where helper (Left err) = error $ show err
        helper (Right x) = x

instance Show Term where
  show (Var x) = x
  show (Abs x (Var y)) = absHead ++ x ++ absOpr ++ y
  show (Abs x y) = absHead ++ x ++ absOpr ++ show y
  show (App x y) = helper1 x ++ appOpr ++ helper2 y
    where helper1 (Var a) = a
          helper1 a@(App _ _) = show a
          helper1 a = "(" ++ show a ++ ")"
          helper2 (Var a) = a
          helper2 a@(Abs _ _) = show a
          helper2 a = "(" ++ show a ++ ")"

-- Theory part

lgh :: Term -> Int
lgh (Var _) = 1
lgh (App x y) = lgh x + lgh y
lgh (Abs _ y) = 1 + lgh y

occurs :: Term -> Term -> Bool
p `occurs` q
  | p == q = True
  | otherwise = helper p q
  where helper m (App x y) = (m `occurs` x) || (m `occurs` y)
        helper m (Abs x y) = (m == Var x) || (m `occurs` y)
        helper _ _ = False

freeVars :: Term -> [Ide]
freeVars (Var x) = [x]
freeVars (App t1 t2) = union (freeVars t1) (freeVars t2)
freeVars (Abs x t) = delete x $ freeVars t

isClosed :: Term -> Bool
isClosed x = freeVars x == []

subst :: Term -> Ide -> Term -> Term
subst n x m@(Var y)
  | x == y = n
  | otherwise = m
subst n x (App p q) = App (subst n x p) (subst n x q)
subst n x m@(Abs y p)
  | x == y = m
  | x `notElem` freeP = m
  | y `notElem` freeN = Abs y (subst n x p)
  | otherwise = Abs z $ subst n x $ subst (Var z) y p
  where freeP = freeVars p
        freeN = freeVars n
        freeNP = union freeP freeN
        z = head $ filter (`notElem` freeNP) allWords

allWords :: [String]
allWords = concat $ iterate addPrefix initVars
  where addPrefix s = [a:b | a <- alphabet, b<-s]
        initVars = map (\x->[x]) alphabet
        alphabet = ['a'..'z']
