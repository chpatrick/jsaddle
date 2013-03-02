{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
-----------------------------------------------------------------------------
--
-- Module      :  Language.Javascript.JSC.Value
-- Copyright   :  (c) Hamish Mackenzie
-- License     :  MIT
--
-- Maintainer  :  Hamish Mackenzie <Hamish.K.Mackenzie@googlemail.com>
--
-- | Deals with JavaScript values.  These can be
--
--   * null
--
--   * undefined
--
--   * true | false
--
--   * a double precision floating point number
--
--   * a string
--
--   * an object
--
-----------------------------------------------------------------------------

module Language.Javascript.JSC.Value (
  -- * JavaScript value references
    JSValueRef
  , MakeValueRef(..)

  -- * Haskell types for JavaScript values
  , JSNull(..)
  , JSUndefined(..)
  , JSBool(..)
  , JSNumber(..)
  , JSString(..)
  , JSValue(..)

  -- * Converting JavaScript values
  , valToBool
  , valToNumber
  , valToStr
  , valToObject
  , valToText

  -- * Make JavaScript values from Haskell ones
  , val
  , valMakeNull
  , valMakeUndefined
  , valMakeBool
  , valMakeNumber
  , valMakeString

  -- * Conver to and from JSValue
  , deRefVal
  , valMakeRef
) where

import Prelude hiding (catch)
import Graphics.UI.Gtk.WebKit.JavaScriptCore.JSBase
       (JSValueRefRef, JSObjectRef, JSStringRef, JSValueRef)
import Language.Javascript.JSC.Monad (JSC, catchval)
import Language.Javascript.JSC.Exception (rethrow)
import Control.Monad.Trans.Reader (ask)
import Control.Monad.IO.Class (MonadIO, MonadIO(..))
import Graphics.UI.Gtk.WebKit.JavaScriptCore.JSValueRef
       (JSType(..), jsvaluegettype, jsvaluemakestring, jsvaluemakenumber,
        jsvaluemakeboolean, jsvaluemakeundefined, jsvaluemakenull,
        jsvaluetoobject, jsvaluetostringcopy, jsvaluetonumber,
        jsvaluetoboolean)
import Graphics.UI.Gtk.WebKit.JavaScriptCore.JSStringRef
       (jsstringcreatewithcharacters, jsstringgetcharactersptr,
        jsstringgetlength)
import qualified Data.Text.Foreign as T (fromPtr)
import Foreign (castPtr)
import Data.Text.Foreign (useAsPtr)
import Control.Applicative ((<$>))
import Data.Text (Text)
import qualified Data.Text as T (pack)
import Language.Javascript.JSC.Classes
       (MakeObjectRef(..), MakeStringRef(..), MakeValueRef(..),
        MakeArgRefs(..))
import Language.Javascript.JSC.String (strToText, textToStr)
import Language.Javascript.JSC.Arguments ()

data JSNull      = JSNull -- ^ Type that represents a value that can only be null.
                          --   Haskell of course has no null so we are adding this type.
type JSUndefined = ()     -- ^ A type that can only be undefined in JavaScript.  Using ()
                          --   because functions in JavaScript that have no return, impicitly
                          --   return undefined.
type JSBool      = Bool   -- ^ JavaScript boolean values map the 'Bool' haskell type.
type JSNumber    = Double -- ^ A number in JavaScript maps nicely to 'Double'.
type JSString    = Text   -- ^ JavaScript strings can be represented with the Haskell 'Text' type.

-- | An algebraic data type that can represent a JavaScript value.  Any JavaScriptCore
--   'JSValueRef' can be converted into this type.
data JSValue = ValNull                   -- ^ null
             | ValUndefined              -- ^ undefined
             | ValBool      JSBool       -- ^ true or false
             | ValNumber    JSNumber     -- ^ a number
             | ValString    JSString     -- ^ a string
             | ValObject    JSObjectRef  -- ^ an object
             deriving(Show, Eq)

-- | Given a JavaScript value get its boolean value.
--   All values in JavaScript convert to bool.
--
-- >>> testJSC $ valToBool JSNull
-- false
-- >>> testJSC $ valToBool ()
-- false
-- >>> testJSC $ valToBool True
-- true
-- >>> testJSC $ valToBool False
-- false
-- >>> testJSC $ valToBool (1.0 :: Double)
-- true
-- >>> testJSC $ valToBool (0.0 :: Double)
-- false
-- >>> testJSC $ valToBool ""
-- false
-- >>> testJSC $ valToBool "1"
-- true
valToBool :: MakeValueRef val => val -> JSC JSBool
valToBool val = do
    gctxt <- ask
    rval <- makeValueRef val
    liftIO $ jsvaluetoboolean gctxt rval

-- | Given a JavaScript value get its numeric value.
--   May throw JSException.
--
-- >>> testJSC $ show <$> valToNumber JSNull
-- 0.0
-- >>> testJSC $ show <$> valToNumber ()
-- NaN
-- >>> testJSC $ show <$> valToNumber True
-- 1.0
-- >>> testJSC $ show <$> valToNumber False
-- 0.0
-- >>> testJSC $ show <$> valToNumber (1.0 :: Double)
-- 1.0
-- >>> testJSC $ show <$> valToNumber (0.0 :: Double)
-- 0.0
-- >>> testJSC $ show <$> valToNumber ""
-- 0.0
-- >>> testJSC $ show <$> valToNumber "1"
-- 1.0
valToNumber :: MakeValueRef val => val -> JSC JSNumber
valToNumber val = do
    gctxt <- ask
    rval <- makeValueRef val
    rethrow $ liftIO . jsvaluetonumber gctxt rval

-- | Given a JavaScript value get its string value (as a JavaScript string).
--   May throw JSException.
--
-- >>> testJSC $ valToStr JSNull >>= strToText
-- null
-- >>> testJSC $ valToStr () >>= strToText
-- undefined
-- >>> testJSC $ valToStr True >>= strToText
-- true
-- >>> testJSC $ valToStr False >>= strToText
-- false
-- >>> testJSC $ valToStr (1.0 :: Double) >>= strToText
-- 1
-- >>> testJSC $ valToStr (0.0 :: Double) >>= strToText
-- 0
-- >>> testJSC $ valToStr "" >>= strToText
--
-- >>> testJSC $ valToStr "1" >>= strToText
-- 1
valToStr :: MakeValueRef val => val -> JSC JSStringRef
valToStr val = do
    gctxt <- ask
    rval <- makeValueRef val
    rethrow $ liftIO . jsvaluetostringcopy gctxt rval

-- | Given a JavaScript value get its string value (as a Haskell 'Text').
--   May throw JSException.
--
-- >>> testJSC $ show <$> valToText JSNull
-- "null"
-- >>> testJSC $ show <$> valToText ()
-- "undefined"
-- >>> testJSC $ show <$> valToText True
-- "true"
-- >>> testJSC $ show <$> valToText False
-- "false"
-- >>> testJSC $ show <$> valToText (1.0 :: Double)
-- "1"
-- >>> testJSC $ show <$> valToText (0.0 :: Double)
-- "0"
-- >>> testJSC $ show <$> valToText ""
-- ""
-- >>> testJSC $ show <$> valToText "1"
-- "1"
valToText :: MakeValueRef val => val -> JSC Text
valToText jsvar = valToStr jsvar >>= strToText

-- | Given a JavaScript value get its object value.
--   May throw JSException.
--
-- >>> testJSC $ (valToObject JSNull >>= valToText) `catch` \ (JSException e) -> valToText e
-- TypeError: 'null' is not an object
-- >>> testJSC $ (valToObject () >>= valToText) `catch` \ (JSException e) -> valToText e
-- TypeError: 'undefined' is not an object
-- >>> testJSC $ valToObject True
-- true
-- >>> testJSC $ valToObject False
-- false
-- >>> testJSC $ valToObject (1.0 :: Double)
-- 1
-- >>> testJSC $ valToObject (0.0 :: Double)
-- 0
-- >>> testJSC $ valToObject ""
--
-- >>> testJSC $ valToObject "1"
-- 1
valToObject :: MakeValueRef val => val -> JSC JSObjectRef
valToObject val = do
    gctxt <- ask
    rval <- makeValueRef val
    rethrow $ liftIO . jsvaluetoobject gctxt rval

-- | Convert to a JavaScript value (just an alias for 'makeValueRef')
val :: MakeValueRef value
    => value          -- ^ value to convert to a JavaScript value
    -> JSC JSValueRef
val = makeValueRef

-- | If we already have a JSValueRef we are fine
instance MakeValueRef JSValueRef where
    makeValueRef = return

-- | A single JSValueRef can be used as the argument list
instance MakeArgRefs JSValueRef where
    makeArgRefs arg = return [arg]

-- | JSValueRef can be made by evaluating a function in 'JSC' as long
--   as it returns something we can make into a JSValueRef.
instance MakeValueRef v => MakeValueRef (JSC v) where
    makeValueRef v = v >>= makeValueRef

----------- null ---------------
-- | Make a @null@ JavaScript value
valMakeNull :: JSC JSValueRef
valMakeNull = ask >>= (liftIO . jsvaluemakenull)

-- | Makes a @null@ JavaScript value
instance MakeValueRef JSNull where
    makeValueRef = const valMakeNull

-- | Makes an argument list with just a single @null@ JavaScript value
instance MakeArgRefs JSNull where
    makeArgRefs _ = valMakeNull >>= (\ref -> return [ref])

----------- undefined ---------------
-- | Make an @undefined@ JavaScript value
valMakeUndefined :: JSC JSValueRef
valMakeUndefined = ask >>= (liftIO . jsvaluemakeundefined)

-- | Makes an @undefined@ JavaScript value
instance MakeValueRef JSUndefined where
    makeValueRef = const valMakeUndefined

--We can't allow this if JSUndefined is () as () is no args not "(null)".
--Use [()] instead.
--instance MakeArgRefs JSUndefined where
--    makeArgRefs _ = valMakeUndefined >>= (\ref -> return [ref])

-- | This allows us to pass no arguments easily (altenative would be to use @[]::[JSValueRef]@).
instance MakeArgRefs () where
    makeArgRefs _ = return []

----------- booleans ---------------
-- | Make a JavaScript boolean value
valMakeBool :: JSBool -> JSC JSValueRef
valMakeBool b = do
    gctxt <- ask
    liftIO $ jsvaluemakeboolean gctxt b

-- | Make a JavaScript boolean value
instance MakeValueRef Bool where
    makeValueRef = valMakeBool

-- | Makes an argument list with just a single JavaScript boolean value
instance MakeArgRefs Bool where
    makeArgRefs b = valMakeBool b >>= (\ref -> return [ref])

----------- numbers ---------------
-- | Make a JavaScript number
valMakeNumber :: JSNumber -> JSC JSValueRef
valMakeNumber n = do
    gctxt <- ask
    liftIO $ jsvaluemakenumber gctxt n

-- | Makes a JavaScript number
instance MakeValueRef Double where
    makeValueRef = valMakeNumber

-- | Makes an argument list with just a single JavaScript number
instance MakeArgRefs Double where
    makeArgRefs n = valMakeNumber n >>= (\ref -> return [ref])

----------- numbers ---------------
-- | Make a JavaScript string
valMakeString :: Text -> JSC JSValueRef
valMakeString text = do
    gctxt <- ask
    liftIO $ jsvaluemakestring gctxt (textToStr text)

-- | Makes a JavaScript string
instance MakeValueRef Text where
    makeValueRef = valMakeString

-- | Makes an argument list with just a single JavaScript string
instance MakeArgRefs Text where
    makeArgRefs t = valMakeString t >>= (\ref -> return [ref])

-- | Makes a JavaScript string
instance MakeValueRef String where
    makeValueRef = valMakeString . T.pack

-- | Derefernce a value reference.
--
-- >>> testJSC $ show <$> deRefVal JSNull
-- ValNull
-- >>> testJSC $ show <$> deRefVal ()
-- ValUndefined
-- >>> testJSC $ show <$> deRefVal True
-- ValBool True
-- >>> testJSC $ show <$> deRefVal False
-- ValBool False
-- >>> testJSC $ show <$> deRefVal (1.0 :: Double)
-- ValNumber 1.0
-- >>> testJSC $ show <$> deRefVal (0.0 :: Double)
-- ValNumber 0.0
-- >>> testJSC $ show <$> deRefVal ""
-- ValString ""
-- >>> testJSC $ show <$> deRefVal "1"
-- ValString "1"
-- >>> testJSC $ show <$> valToObject True >>= deRefVal
-- ValObject 0x...
deRefVal :: MakeValueRef val => val -> JSC JSValue
deRefVal val = do
    gctxt <- ask
    valref <- makeValueRef val
    t <- liftIO $ jsvaluegettype gctxt valref
    case t of
        Kjstypenull      -> return ValNull
        Kjstypeundefined -> return ValUndefined
        Kjstypeboolean   -> ValBool   <$> valToBool valref
        Kjstypenumber    -> ValNumber <$> valToNumber valref
        Kjstypestring    -> ValString <$> (valToStr valref >>= strToText)
        Kjstypeobject    -> ValObject <$> valToObject valref

-- | Make a JavaScript value out of a 'JSValue' ADT.
--
-- >>> testJSC $ valMakeRef ValNull
-- "null"
-- >>> testJSC $ valMakeRef ValUndefined
-- "undefined"
-- >>> testJSC $ valMakeRef (ValBool True)
-- "true"
-- >>> testJSC $ valMakeRef (ValNumber 1)
-- "1"
-- >>> testJSC $ valMakeRef (ValString $ pack "Hello")
-- "Hello"
valMakeRef :: JSValue -> JSC JSValueRef
valMakeRef val =
    case val of
        ValNull      -> valMakeNull
        ValUndefined -> valMakeUndefined
        ValBool b    -> valMakeBool b
        ValNumber n  -> valMakeNumber n
        ValString s  -> valMakeString s
        ValObject o  -> return o

-- | Makes a JavaScript value from a 'JSValue' ADT.
instance MakeValueRef JSValue where
    makeValueRef = valMakeRef

-- | Makes an argument list with just a single JavaScript value from a 'JSValue' ADT.
instance MakeArgRefs JSValue where
    makeArgRefs v = valMakeRef v >>= (\ref -> return [ref])

instance MakeObjectRef JSNull where
    makeObjectRef = const valMakeNull
