module EventStore where

import Prelude
import Control.Monad.Except.Trans (class MonadError, ExceptT, runExceptT, withExceptT)
import Data.Argonaut (class EncodeJson, Json, jsonEmptyObject)
import Data.Argonaut.Encode.Combinators ((:=), (~>))
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Database.PostgreSQL.PG (class FromSQLRow, Connection, PGError, Pool, Query(Query), defaultPoolConfiguration, fromSQLValue, newPool, query)
import Database.PostgreSQL.PG as PG
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff)
import Effect.Class (liftEffect)
import Types (EventId(..), Result, Limit(..))

type EventStore
  = { events :: EventId -> Limit -> Result (Array Event) }

newtype Event
  = Event
  { id :: EventId
  , data :: Json
  }

instance eventToJson :: EncodeJson Event where
  encodeJson (Event event) =
    "offset" := unwrap event.id
      ~> ("payload" := event.data)
      ~> jsonEmptyObject
    where
    unwrap (EventId id) = id

instance fromSQLRowFoo :: FromSQLRow Event where
  fromSQLRow [ idValue, dataValue ] = (\id data' -> Event { id: EventId id, data: data' }) <$> fromSQLValue idValue <*> fromSQLValue dataValue
  fromSQLRow _ = Left "Expecting exactly two more fields."

type PG a
  = ExceptT PGError Aff a

withConnection :: ∀ a. Pool -> (Connection -> PG a) -> PG a
withConnection = PG.withConnection runExceptT

newtype DbName
  = DbName String

newtype DbUser
  = DbUser String

newtype DbPass
  = DbPass String

newtype DbHost
  = DbHost String

eventStore :: DbHost -> DbName -> DbUser -> DbPass -> Result EventStore
eventStore (DbHost host) (DbName name) (DbUser user) (DbPass pass) = do
  pool <- liftEffect $ newPool config
  pure { events: \id limit -> withExceptT show $ withConnection pool (events id limit) }
  where
  config =
    (defaultPoolConfiguration name)
      { idleTimeoutMillis = Just 1000
      , user = Just user
      , password = Just pass
      , host = Just host
      , max = Just 2
      }

events :: ∀ m. Bind m => MonadError PGError m => MonadAff m => EventId -> Limit -> Connection -> m (Array Event)
events (EventId id) (Limit limit) conn = query conn (Query sql) (id /\ limit)
  where
  sql =
    """
      SELECT id, data
      FROM events
      WHERE id > $1
      ORDER BY id ASC
      LIMIT $2
    """
