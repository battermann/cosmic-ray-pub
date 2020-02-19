module Test.Main where

import Data.Argonaut.Core (fromString, stringify)
import EventStore (Event(..))
import Prelude (Unit, (#), ($))
import Types (EventId(..))
import Data.Argonaut (encodeJson)
import Effect (Effect)
import Effect.Class.Console (log)

main :: Effect Unit
main = do
  log $ encodeJson event # stringify
  where
  event = Event { id: EventId 0, data: fromString "Hello" }
