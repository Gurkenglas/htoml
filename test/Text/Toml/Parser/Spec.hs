{-# LANGUAGE OverloadedStrings #-}

module Text.Toml.Parser.Spec (tomlParserSpec) where

import Test.Tasty (TestTree)
import Test.Tasty.Hspec

import Control.Applicative ((<*))
import Text.Parsec
import qualified Data.Map as M
import Data.Time.Clock (UTCTime(..))
import Data.Time.Calendar (Day(..))

import Text.Toml.Parser


tomlParserSpec :: IO TestTree
tomlParserSpec = testSpec "parser tests" tomlParserSpec'

tomlParserSpec' :: Spec
tomlParserSpec' = do


  describe "Parser.tomlDoc generic" $ do

    it "should parse empty input" $
      testParser tomlDoc "" $ TomlDoc M.empty []

    it "should parse non-empty tomlDocs that do not end with a newline" $
      testParser tomlDoc "number = 123" $
        TomlDoc (M.fromList [("number", VInteger 123)]) []

    it "should parse when tomlDoc ends in a comment" $
      testParser tomlDoc "q = 42  # understood?" $
        TomlDoc (M.fromList [("q", VInteger 42)]) []

    it "should not parse re-assignment of key" $
      testParserFails tomlDoc "q=42\nq=42"

    it "should not parse rubbish" $
      testParserFails tomlDoc "{"


  describe "Parser.tomlDoc (named tables)" $ do

    it "should parse simple named table" $
      testParser tomlDoc "[a]\naa = 108" $
        TomlDoc M.empty [ TableNode "a" (Just . Left $ M.fromList [("aa", VInteger 108)]) [] ]

    it "should not parse redefined table header" $
      testParserFails tomlDoc "[a]\n[a]"

    it "should parse redefined implicit table header" $
      testParser tomlDoc "[a.b]\n[a]" $
        TomlDoc M.empty [ TableNode "a" (Just . Left $ M.empty)
                                        [TableNode "b" (Just . Left $ M.empty) []] ]

    it "should not parse redefinition by implicit table header" $
      testParserFails tomlDoc "[a]\n[a.b]"


  describe "Parser.tomlDoc (tables arrays)" $ do

    it "should parse a simple table array" $
      testParser tomlDoc "[[a]]\na1=1\n[[a]]\na2=2" $
        TomlDoc M.empty [ TableNode "a" (Just . Right $ [ M.fromList [("a1", VInteger 1)]
                                                        , M.fromList [("a2", VInteger 2)] ]) [] ]
    it "should parse a simple empty table array" $
      testParser tomlDoc "[[a]]\n[[a]]" $
        TomlDoc M.empty [ TableNode "a" (Just . Right $ [ M.empty, M.empty ]) [] ]

    it "should parse a simple empty table array" $
      testParser tomlDoc "[[a.b]]\n[[a.b]]" $
        TomlDoc M.empty [ TableNode "a" Nothing [
          TableNode "b" (Just . Right $ [ M.empty, M.empty ]) [] ] ]

    it "should parse a simple empty table array" $
      testParser tomlDoc "[[a.b]]\na1=1\n[[a.b]]\na2=2" $
        TomlDoc M.empty [ TableNode "a" Nothing [
          TableNode "b" (Just . Right $ [ M.fromList [("a1", VInteger 1)]
                                        , M.fromList [("a2", VInteger 2)] ]) [] ] ]

    it "should parse redefined implicit table header" $
      testParser tomlDoc "[[a.b]]\n[[a]]" $
        TomlDoc M.empty [ TableNode "a" (Just . Right $ [ M.empty ]) [
          TableNode "b" (Just . Right $ [ M.empty ]) [] ] ]

    it "should not parse redefinition by implicit table header" $
      testParserFails tomlDoc "[[a]]\n[[a.b]]"


  describe "Parser.tomlDoc (mixed named tables and tables arrays)" $ do

    it "should not parse redefined table header (array by table)" $
      testParserFails tomlDoc "[[a]]\n[a]"

    it "should not parse redefined table header (table by array)" $
      testParserFails tomlDoc "[a]\n[[a]]"

    it "should not parse redefinition by implicit table header (array by table)" $
      testParserFails tomlDoc "[[a]]\n[a.b]"

    it "should not parse redefinition by implicit table header (table by array)" $
      testParserFails tomlDoc "[a]\n[[a.b]]"


    it "should parse redefined implicit table header (table by array)" $
      testParser tomlDoc "[a.b]\n[[a]]" $
        TomlDoc M.empty [ TableNode "a" (Just . Right $ [ M.empty ]) [
          TableNode "b" (Just . Left $ M.empty) [] ] ]

    it "should parse redefined implicit table header (array by table)" $
      testParser tomlDoc "[[a.b]]\n[a]" $
        TomlDoc M.empty [ TableNode "a" (Just . Left $ M.empty) [
          TableNode "b" (Just . Right $ [ M.empty ]) [] ] ]


  describe "Parser.headerValue" $ do

    it "should parse simple table header" $
      testParser headerValue "table" ["table"]

    it "should parse simple nested table header" $
      testParser headerValue "main.sub" ["main", "sub"]

    it "should not parse just a dot (separator)" $
      testParserFails headerValue "."

    it "should not parse an empty most right name" $
      testParserFails headerValue  "first."

    it "should not parse an empty most left name" $
      testParserFails headerValue  ".second"

    it "should not parse an empty middle name" $
      testParserFails headerValue  "first..second"


  describe "Parser.tableHeader" $ do

    it "should not parse an empty table header" $
      testParserFails tableHeader "[]"

    it "should parse simple table header" $
      testParser tableHeader "[item]" ["item"]

    it "should parse simple nested table header" $
      testParser tableHeader "[main.sub]" ["main", "sub"]


  describe "Parser.tableArrayHeader" $ do

    it "should not parse an empty table header" $
      testParserFails tableArrayHeader "[[]]"

    it "should parse simple table array header" $
      testParser tableArrayHeader "[[item]]" ["item"]

    it "should parse simple nested table array header" $
      testParser tableArrayHeader "[[main.sub]]" ["main", "sub"]


  describe "Parser.assignment" $ do

    it "should parse simple example" $
      testParser assignment "country = \"\"" ("country", VString "")

    it "should parse without spacing around the assignment operator" $
      testParser assignment "a=108" ("a", VInteger 108)

    it "should parse when value on next line" $
      testParser assignment "a =\n108" ("a", VInteger 108)

    it "should parse when assignment operator and value are on the next line" $
      testParser assignment "a\n= 108" ("a", VInteger 108)

    it "should parse when key, value and assignment operator are on separate lines" $
      testParser assignment "a\n=\n108" ("a", VInteger 108)


  describe "Parser.boolean" $ do

    it "should parse true" $
      testParser boolean "true" $ VBoolean True

    it "should parse false" $
      testParser boolean "false" $ VBoolean False

    it "should not parse capitalized variant" $
      testParserFails boolean "False"


  describe "Parser.basicStr" $ do

    it "should parse the common escape sequences in basic strings" $
      testParser basicStr "\"123\\b\\t\\n\\f\\r\\\"\\/\\\\\"" $ VString "123\b\t\n\f\r\"/\\"

    it "should parse the simple unicode value from the example" $
      testParser basicStr "\"中国\"" $ VString "中国"

    it "should parse escaped 4 digit unicode values" $
      testParser assignment "special_k = \"\\u0416\"" ("special_k", VString "Ж")

    it "should parse escaped 8 digit unicode values" $
      testParser assignment "g_clef = \"\\U0001D11e\"" ("g_clef", VString "𝄞")

    it "should not parse escaped unicode values with missing digits" $
      testParserFails assignment "g_clef = \"\\U1D11e\""


  describe "Parser.multiBasicStr" $ do

    it "should parse simple example" $
      testParser multiBasicStr "\"\"\"thorrough\"\"\"" $ VString "thorrough"

    it "should parse with newlines" $
      testParser multiBasicStr "\"\"\"One\nTwo\"\"\"" $ VString "One\nTwo"

    it "should parse with escaped newlines" $
      testParser multiBasicStr "\"\"\"One\\nTwo\"\"\"" $ VString "One\nTwo"

    it "should parse newlines, ignoring 1 leading newline" $
      testParser multiBasicStr "\"\"\"\nOne\\nTwo\"\"\"" $ VString "One\nTwo"

    it "should parse with espaced whitespace" $
      testParser multiBasicStr "\"\"\"\\\n\
                               \Quick \\\n\
                               \\\\n\
                               \Jumped \\\n\
                               \Lazy\\\n\
                               \ \"\"\"" $ VString "Quick Jumped Lazy"


  describe "Parser.literalStr" $ do

    it "should parse literally" $
      testParser literalStr "'\"Your\" folder: \\\\User\\new\\tmp\\'" $
                            VString "\"Your\" folder: \\\\User\\new\\tmp\\"

    it "has no notion of 'escaped single quotes'" $
      testParserFails tomlDoc "q = 'I don\\'t know.'"  -- string terminates before the "t"


  describe "Parser.multiLiteralStr" $ do

    it "should parse literally" $
      testParser multiLiteralStr
        "'''\nFirst newline is dropped.\n   Other whitespace,\n  is preserved -- isn't it?'''"
        $ VString "First newline is dropped.\n   Other whitespace,\n  is preserved -- isn't it?"


  describe "Parser.datetime" $ do

    it "should parse a JSON formatted datetime string in zulu timezone" $
      testParser datetime "1979-05-27T07:32:00Z" $
        VDatetime $ UTCTime (ModifiedJulianDay 44020) 27120

    it "should not parse only dates" $
      testParserFails datetime "1979-05-27"

    it "should not parse without the Z" $
      testParserFails datetime "1979-05-27T07:32:00"


  describe "Parser.float" $ do

    it "should parse positive floats" $
      testParser float "3.14" $ VFloat 3.14

    it "should parse negative floats" $
      testParser float "-0.1" $ VFloat (-0.1)

    it "should parse more or less zero float" $
      testParser float "0.0" $ VFloat 0.0

    it "should not accept floats starting with a dot" $
      testParserFails float ".5"

    it "should not accept floats without any decimals" $
      testParserFails float "5."

    it "should not accept 'scientific notation' ('e'-notation) of numbers" $
      testParserFails assignment "a_million_and_a_half = 1.5e6"

    it "should not allow floats prefixed with a plus" $
      testParserFails float "+2.1828"


  describe "Parser.integer" $ do

    it "should parse positive integers" $
      testParser integer "108" $ VInteger 108

    it "should parse negative integers" $
      testParser integer "-1" $ VInteger (-1)

    it "should parse zero" $
      testParser integer "0" $ VInteger 0

    it "should not allow integers prefixed with a plus" $
      testParserFails integer "+42"


  describe "Parser.tomlDoc arrays" $ do

    it "should parse nested arrays" $
      testParser assignment "d = [ [\"gamma\", \"delta\"], [1, 2] ]"
              $ ("d", VArray [ VArray [ VString "gamma"
                                      , VString "delta" ]
                             , VArray [ VInteger 1
                                      , VInteger 2 ] ])

    it "should allow linebreaks in an array" $
      testParser assignment "hosts = [\n'alpha',\n'omega'\n]"
        $ ("hosts", VArray [VString "alpha", VString "omega"])

    it "should allow some linebreaks in an array" $
      testParser assignment "hosts = ['alpha' ,\n'omega']"
        $ ("hosts", VArray [VString "alpha", VString "omega"])

    it "should allow linebreaks in an array, with comments" $
      testParser assignment "hosts = [\n\
                            \'alpha',  # the first\n\
                            \'omega'   # the last\n\
                            \]"
        $ ("hosts", VArray [VString "alpha", VString "omega"])

    it "should allow linebreaks in an array, with comments, and terminating comma" $
      testParser assignment "hosts = [\n\
                            \'alpha',  # the first\n\
                            \'omega'   # the last\n\
                            \]"
        $ ("hosts", VArray [VString "alpha", VString "omega"])

    it "inside an array, all element should be of the same type" $
      testParserFails array "[1, 2.0]"

    it "inside an array of arrays, this inner arrays may contain values of different types" $
      testParser array "[[1], [2.0], ['a']]" $
        VArray [ VArray [VInteger 1], VArray [VFloat 2.0], VArray [VString "a"] ]

    it "all string variants are of the same type of the same type" $
      testParser assignment "data = [\"a\", \"\"\"b\"\"\", 'c', '''d''']" $
                            ("data", VArray [ VString "a", VString "b",
                                                      VString "c", VString "d" ])

    it "should parse terminating commas in arrays" $
      testParser array "[1, 2, ]" $ VArray [ VInteger 1, VInteger 2 ]

    it "should parse terminating commas in arrays(2)" $
      testParser array "[1,2,]" $ VArray [ VInteger 1, VInteger 2 ]


  where testParser p str success = case parse (p <* eof) "test" str of
                                     Left  _ -> False
                                     Right x -> x == success
        testParserFails p str    = case parse (p <* eof) "test" str of
                                     Left  _ -> True
                                     Right _ -> False
