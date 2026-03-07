module Agent.Fork
  ( PiConfig (..),
    defaultPiConfig,
    piChannel,
  )
where

import Control.Monad (unless)
import System.Directory (doesFileExist)
import System.IO
import System.Process

-- | Configuration for the pi agent channel
data PiConfig = PiConfig
  { -- | Command to run (e.g., "pi")
    processCommand :: String,
    -- | Working directory
    workDir :: FilePath,
    -- | Path to stdin FIFO
    stdinPath :: FilePath,
    -- | Path to stdout log file
    stdoutPath :: FilePath,
    -- | Path to stderr log file
    stderrPath :: FilePath
  }
  deriving (Show, Eq)

-- | Default pi channel configuration
defaultPiConfig :: PiConfig
defaultPiConfig =
  PiConfig
    { processCommand = "pi",
      workDir = ".",
      stdinPath = "/tmp/pi-in",
      stdoutPath = "./log/pi-stdout.md",
      stderrPath = "./log/pi-stderr.md"
    }

-- | Ensure a FIFO exists, creating it if necessary
ensureFifo :: FilePath -> IO ()
ensureFifo path = do
  exists <- doesFileExist path
  unless exists $ do
    callProcess "mkfifo" [path]

-- | Start a pi agent session with named pipes
--
-- Creates stdin FIFO if it doesn't exist.
-- Opens handles for stdin (FIFO), stdout, and stderr (append mode).
-- Spawns the process with those handles wired.
-- Returns a ProcessHandle to the running process.
piChannel :: PiConfig -> IO ProcessHandle
piChannel cfg = do
  -- Create stdin FIFO if it doesn't exist
  ensureFifo (stdinPath cfg)

  -- Open stdin FIFO for reading
  stdinHandle <- openFile (stdinPath cfg) ReadMode

  -- Open stdout and stderr for appending
  stdoutHandle <- openFile (stdoutPath cfg) AppendMode
  stderrHandle <- openFile (stderrPath cfg) AppendMode

  -- Set no buffering for immediate output
  hSetBuffering stdoutHandle NoBuffering
  hSetBuffering stderrHandle NoBuffering

  -- Create the process specification
  let procSpec =
        (shell (processCommand cfg))
          { cwd = Just (workDir cfg),
            std_in = UseHandle stdinHandle,
            std_out = UseHandle stdoutHandle,
            std_err = UseHandle stderrHandle
          }

  -- Spawn the process
  (_, _, _, ph) <- createProcess procSpec

  return ph
