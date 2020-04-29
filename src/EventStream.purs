module EventStream (EventStream, eventStream, RedisUrl(..)) where

import Prelude
import Control.Monad.Except (ExceptT(..), withExceptT)
import Control.Promise (Promise)
import Control.Promise as Promise
import Data.Argonaut (encodeJson, stringify)
import Data.Int (fromString)
import Data.Maybe (Maybe)
import Effect.Aff (attempt)
import Effect.Aff.Compat (EffectFnAff, fromEffectFnAff)
import Effect.Class (liftEffect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import EventStore (Event)
import Types (EventId(..), Result)

type EventStream
  = { getLatestPublishedEventId :: Result (Maybe EventId)
    , setLatestPublishedEventId :: EventId -> Result Unit
    , append :: Event -> Result Unit
    , quit :: Result Unit
    }

foreign import data RedisClient :: Type

foreign import createClientImpl :: String -> EffectFnAff RedisClient

createClient :: String -> Result RedisClient
createClient url = fromEffectFnAff (createClientImpl url) # attempt # ExceptT # withExceptT show

foreign import quitClientImpl :: EffectFn1 RedisClient Unit

quitClient :: RedisClient -> Result Unit
quitClient = runEffectFn1 quitClientImpl >>> liftEffect >>> attempt >>> ExceptT >>> withExceptT show

foreign import getIndexImpl :: EffectFn1 RedisClient (Promise String)

getIndex :: RedisClient -> Result (Maybe EventId)
getIndex client =
  runEffectFn1 getIndexImpl client
    # Promise.toAffE
    # attempt
    <#> map (fromString >>> map EventId)
    # ExceptT
    # withExceptT show

foreign import setIndexImpl :: EffectFn2 RedisClient Int (Promise Unit)

setIndex :: RedisClient -> EventId -> Result Unit
setIndex client (EventId i) =
  runEffectFn2 setIndexImpl client i
    # Promise.toAffE
    # attempt
    # ExceptT
    # withExceptT show

foreign import appendToEventsImpl :: EffectFn2 RedisClient String (Promise Unit)

appendToEvents :: RedisClient -> Event -> Result Unit
appendToEvents client event =
  runEffectFn2 appendToEventsImpl client json
    # Promise.toAffE
    # attempt
    # ExceptT
    # withExceptT show
  where
  json = encodeJson event # stringify

newtype RedisHost
  = RedisHost String

newtype RedisPort
  = RedisPort Int

newtype RedisUrl
  = RedisUrl String

eventStream :: RedisUrl -> Result EventStream
eventStream (RedisUrl url) = do
  client <- createClient url
  pure (fromClient client)
  where
  fromClient client =
    { getLatestPublishedEventId: getIndex client
    , setLatestPublishedEventId: setIndex client
    , append: appendToEvents client
    , quit: quitClient client
    }
