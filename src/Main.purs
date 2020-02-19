module Main where

import Prelude
import Control.Monad.Except (lift, runExceptT)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..))
import Debug.Trace (spy)
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay, launchAff_)
import Effect.Class.Console (log)
import EventStore (Event(..), eventStore)
import EventStream (EventStream, eventStream)
import Types (Result, Limit(..), EventId(..))

main :: Effect Unit
main = launchAff_ program

program :: Aff Unit
program = do
  streamOrError <- runExceptT eventStream
  result <- case streamOrError of
    Left err -> pure $ Left err
    Right stream -> do
      result <- runExceptT $ loop stream
      case result of
        Left err -> log $ "An error occurred:\n" <> err <> "\nTerminating program..."
        Right _ -> log "Process completed successfully"
      runExceptT stream.quit
  case result of
    Left err -> log err
    Right _ -> pure unit

loop :: EventStream -> Result Unit
loop stream = do
  es <- eventStore
  maybeId <- stream.getLatestPublishedEventId
  case maybeId of
    Nothing -> stream.setLatestPublishedEventId (EventId 0)
    Just id -> do
      events <- es.events id (Limit 10)
      traverse_ (\(Event event) -> stream.append (Event event) *> stream.setLatestPublishedEventId event.id) events
  lift $ delay (Milliseconds 250.0)
  loop stream
