-- | Like Latency, but creating lots of channels
import System.Environment
import Control.Monad
import Control.Applicative
import Control.Distributed.Process
import Control.Distributed.Process.Node
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Data.Binary (encode, decode)
import qualified Data.ByteString.Lazy as BSL

pingServer :: Process ()
pingServer = forever $ do
  them <- expect
  say $ "got " ++ show them
  sendChan them ()
  -- TODO: should this be automatic?
  reconnectPort them

pingClient :: Int -> ProcessId -> Process ()
pingClient n them = do
  replicateM_ n $ do
    (sc, rc) <- newChan :: Process (SendPort (), ReceivePort ())
    send them sc
    receiveChan rc
  liftIO . putStrLn $ "Did " ++ show n ++ " pings"

initialProcess :: String -> Process ()
initialProcess "SERVER" = do
  us <- getSelfPid
  liftIO $ BSL.writeFile "pingServer.pid" (encode us)
  pingServer
initialProcess "CLIENT" = do
  n <- liftIO $ getLine
  them <- liftIO $ decode <$> BSL.readFile "pingServer.pid"
  pingClient (read n) them

main :: IO ()
main = do
  [role, host, port] <- getArgs
  Right transport <- createTransport host port defaultTCPParameters
  node <- newLocalNode transport initRemoteTable
  runProcess node $ initialProcess role
