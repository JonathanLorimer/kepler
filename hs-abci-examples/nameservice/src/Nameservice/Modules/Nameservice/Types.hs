module Nameservice.Modules.Nameservice.Types where

import           Control.Lens                   (iso, (&), (.~), (^.))
import           Control.Lens.Wrapped           (Wrapped (..))
import           Data.Aeson                     as A
import qualified Data.Binary                    as Binary
import           Data.ByteString                (ByteString)
import           Data.ByteString                as BS
import           Data.Maybe                     (fromJust)
import           Data.ProtoLens.Message         (Message (defMessage))
import           Data.String.Conversions        (cs)
import           Data.Text                      (Text)
import           GHC.Generics                   (Generic)
import           Nameservice.Aeson              (defaultNameserviceOptions)
import           Nameservice.Modules.Token      (Address (..), Amount (..))
import qualified Proto.Nameservice.Whois        as W
import qualified Proto.Nameservice.Whois_Fields as W
import           Tendermint.SDK.Auth            (Address, addressFromBytes,
                                                 addressToBytes)
import           Tendermint.SDK.Codec           (HasCodec (..))
import           Tendermint.SDK.Errors          (AppError (..), IsAppError (..))
import           Tendermint.SDK.Events          (FromEvent (..), ToEvent (..))
import qualified Tendermint.SDK.Router          as R
import qualified Tendermint.SDK.Store           as Store

--------------------------------------------------------------------------------

type NameserviceModule = "nameservice"

--------------------------------------------------------------------------------

newtype Name = Name String deriving (Eq, Show, Binary.Binary, A.ToJSON, A.FromJSON)

data Whois = Whois
  { whoisValue :: String
  , whoisOwner :: Address
  , whoisPrice :: Amount
  } deriving (Eq, Show, Generic)

instance Binary.Binary Whois

instance HasCodec Whois where
  encode = cs . Binary.encode
  decode = Right . Binary.decode . cs

instance Store.RawKey Name where
    rawKey = iso (\(Name n) -> cs n) (Name . cs)

instance Store.IsKey Name NameserviceModule where
    type Value Name NameserviceModule = Whois

instance R.Queryable Whois where
  type Name Whois = "whois"

instance Wrapped Whois where
  type Unwrapped Whois = W.Whois

  _Wrapped' = iso t f
    where
      t Whois{..} =
        let value = cs whoisValue
            owner = addressToBytes whoisOwner
            Amount price = whoisPrice
        in defMessage
          & W.value .~ value
          & W.owner .~ owner
          & W.price .~ price
      f msg =
        let msgValue = cs $ msg ^. W.value
            msgOwner = addressFromBytes $ msg ^. W.owner
            msgPrice = Amount $ msg ^. W.price
        in Whois { whoisValue = msgValue
                 , whoisOwner = msgOwner
                 , whoisPrice = msgPrice
                 }

--------------------------------------------------------------------------------
-- Exceptions
--------------------------------------------------------------------------------

data NameserviceException =
    InsufficientBid Text
  | UnauthorizedSet Text
  | InvalidDelete Text

instance IsAppError NameserviceException where
  makeAppError (InsufficientBid msg) =
    AppError
      { appErrorCode = 1
      , appErrorCodespace = "nameservice"
      , appErrorMessage = msg
      }
  makeAppError (UnauthorizedSet msg) =
    AppError
      { appErrorCode = 2
      , appErrorCodespace = "nameservice"
      , appErrorMessage = msg
      }
  makeAppError (InvalidDelete msg) =
    AppError
      { appErrorCode = 3
      , appErrorCodespace = "nameservice"
      , appErrorMessage = msg
      }

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

data NameClaimed = NameClaimed
  { nameClaimedOwner :: Address
  , nameClaimedName  :: Name
  , nameClaimedValue :: String
  , nameClaimedBid   :: Amount
  } deriving (Generic)

nameClaimedAesonOptions :: A.Options
nameClaimedAesonOptions = defaultNameserviceOptions "nameClaimed"

instance ToJSON NameClaimed where
  toJSON = A.genericToJSON nameClaimedAesonOptions
instance FromJSON NameClaimed where
  parseJSON = A.genericParseJSON nameClaimedAesonOptions
instance ToEvent NameClaimed where
  makeEventType _ = "NameClaimed"

data NameRemapped = NameRemapped
  { nameRemappedName     :: Name
  , nameRemappedOldValue :: String
  , nameRemappedNewValue :: String
  } deriving Generic

nameRemappedAesonOptions :: A.Options
nameRemappedAesonOptions = defaultNameserviceOptions "nameRemapped"

instance ToJSON NameRemapped where
  toJSON = A.genericToJSON nameRemappedAesonOptions
instance FromJSON NameRemapped where
  parseJSON = A.genericParseJSON nameRemappedAesonOptions
instance ToEvent NameRemapped where
  makeEventType _ = "NameRemapped"
instance FromEvent NameRemapped

data NameDeleted = NameDeleted
  { nameDeletedName :: Name
  } deriving Generic

nameDeletedAesonOptions :: A.Options
nameDeletedAesonOptions = defaultNameserviceOptions "nameDeleted"

instance ToJSON NameDeleted where
  toJSON = A.genericToJSON nameDeletedAesonOptions
instance FromJSON NameDeleted where
  parseJSON = A.genericParseJSON nameDeletedAesonOptions
instance ToEvent NameDeleted where
  makeEventType _ = "NameDeleted"
instance FromEvent NameDeleted
