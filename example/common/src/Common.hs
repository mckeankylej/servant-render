{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
module Common where

import Data.Proxy (Proxy(..))
import GHC.Generics
import Data.Aeson (FromJSON,ToJSON)
import qualified Network.HTTP.Media as M
import Servant.API
import Servant.Common.Uri (Uri(..))
import Servant.Render (HasRender(..),Link(..),ServantErr(..),Reflexive)
import Reflex.Dom hiding (Link)
import qualified Data.Text as T
import Text.Read (readMaybe)
import qualified Data.ByteString.Lazy as LB
import qualified Data.ByteString.Lazy.Builder as LB
import Data.Monoid ((<>))

data RunTime

instance Accept RunTime where
  contentType _ = "text" M.// "html" M./: ("charset", "utf-8")

instance MimeRender RunTime a where
  mimeRender _ _ = LB.toLazyByteString $ mconcat
    [ "<!DOCTYPE html>"
    , "<html><head>"
    , script "/rts.js" ""
    , script "/lib.js" ""
    , script "/out.js" ""
    , "</head><body></body>"
    , script "/runmain.js" " defer"
    , "</html>" ]
    where script :: LB.Builder -> LB.Builder -> LB.Builder
          script s attr = mconcat
            [ "<script language=\"javascript\" src=\""
            , s
            , "\""
            , attr
            , "></script>" ]

data Item = Item {
  itemId    :: Int,
  itemName  :: String,
  itemPrice :: Double } deriving (Show,Generic,FromJSON,ToJSON)

type API = "item" :> "all" :> Get '[JSON,RunTime] [Item]
      :<|> "item" :> "one" :> Capture "itemId" Int :> Get '[JSON,RunTime] Item
      :<|> "item" :> "num" :> Reflexive (Get '[JSON] Int)
      :<|> Get '[JSON,RunTime] ()

api :: Proxy API
api = Proxy

item :: MonadWidget t m => Item -> m ()
item (Item i name p) = do
  el "div" $ do
    el "div" $ text $ "Item: "  <> T.pack name
    el "div" $ text $ "Id: "    <> T.pack (show i)
    el "div" $ text $ "Price: " <> T.pack (show p)

widgets :: MonadWidget t m => Links API t m -> Widgets API t m
widgets (jumpAll :<|> jumpOne :<|> eLens :<|> jumpHome) =
  displayAll jumpOne jumpHome :<|> displayOne jumpAll jumpHome :<|> () :<|> displayHome eLens jumpAll
  where displayAll jumpOne jumpHome items = Link $ do
          mapM_ (el "div" . item) items
          el "div" $ text "Jump to an item based off of its id: "
          t <- textInput $ def & textInputConfig_inputType .~ "number"
                               & textInputConfig_initialValue .~ "0"
          unLink $ jumpOne (fmap (maybe 0 id . readMaybe . T.unpack) (_textInput_value t))
                           (fmapMaybe (\x -> if keyCodeLookup x == Enter then Just () else Nothing)
                                      (_textInput_keypress t))
        displayOne jumpAll jumpHome i = Link $ do
          item i
          h <- button "Jump home!"
          unLink (jumpHome h)
        displayHome eLens jumpAll () = Link $ do
          n <- button "Refresh length"
          len <- fmapMaybe hush <$> eLens n
          el "div" $ do
            text "Number of items:"
            holdDyn 0 len >>= display
          a <- button "Jump All!"
          unLink (jumpAll a)
        hush (Left _)  = Nothing
        hush (Right a) = Just a

errorPage :: (Monad m, DomBuilder t m) => Links API t m -> ServantErr -> Link t m
errorPage (_ :<|> _ :<|> _ :<|> jumpHome) err = Link $ do
  el "div" $ text $ "Something went wrong : " <> displayErr err
  b <- button "Jump home!"
  unLink (jumpHome b)
  where displayErr (NotFound err) = "Not Found: " <> err
        displayErr (AjaxFailure err) = "Ajax failure: " <> err

errorPageLoc :: Uri
errorPageLoc = Uri ["error"] []
