module Types where

import Control.Monad.Except (ExceptT)
import Effect.Aff (Aff)

type Result a
  = ExceptT String Aff a

newtype EventId
  = EventId Int

newtype Limit
  = Limit Int
