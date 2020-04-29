module Main where

import Prelude
import Control.Monad.Except (lift, runExceptT)
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), delay, launchAff_)
import Effect.Class.Console (log)
import EventStore (DbHost(..), DbName(..), DbPass(..), DbUser(..), Event(..), EventStore, eventStore)
import EventStream (EventStream, RedisUrl(..), eventStream)
import Node.Process (lookupEnv)
import Types (Result, Limit(..), EventId(..))

main :: Effect Unit
main = do
  redisUrl <- lookupEnv "REDIS_URL" <#> map RedisUrl
  dbHost <- lookupEnv "DB_HOST" <#> map DbHost
  dbName <- lookupEnv "DB_NAME" <#> map DbName
  dbUser <- lookupEnv "DB_USER" <#> map DbUser
  dbPass <- lookupEnv "DB_PASS" <#> map DbPass
  let
    maybeAff =
      program
        <$> redisUrl
        <*> dbHost
        <*> dbName
        <*> dbUser
        <*> dbPass
  case maybeAff of
    Nothing -> log "Please set correct env vars"
    Just p -> launchAff_ p

program :: RedisUrl -> DbHost -> DbName -> DbUser -> DbPass -> Aff Unit
program redisUrl dbHost dbName dbUser dbPass = do
  streamOrError <- runExceptT $ eventStream redisUrl
  esOrError <- runExceptT $ eventStore dbHost dbName dbUser dbPass
  result <- case Tuple <$> streamOrError <*> esOrError of
    Left err -> pure $ Left err
    Right (stream /\ es) -> do
      result <- runExceptT $ loop stream es
      case result of
        Left err -> log $ "An error occurred:\n" <> err <> "\nTerminating program..."
        Right _ -> log "Process completed successfully"
      runExceptT stream.quit
  case result of
    Left err -> log err
    Right _ -> pure unit

loop :: EventStream -> EventStore -> Result Unit
loop stream es = do
  maybeId <- stream.getLatestPublishedEventId
  case maybeId of
    Nothing -> stream.setLatestPublishedEventId (EventId 0)
    Just id -> do
      events <- es.events id (Limit 10)
      traverse_ (\(Event event) -> stream.append (Event event) *> stream.setLatestPublishedEventId event.id) events
  lift $ delay (Milliseconds 250.0)
  loop stream es
