-- | Agentic harness for the pi executable via named pipes.
module Agent.Fork
where

import Control.Monad (unless)
import System.Directory (doesFileExist)
import System.IO
import System.Process

-- $setup
-- Named pipes (FIFOs) decouple agent I/O from console buffering.
-- Agents write queries to stdin, spawn returns immediately, 
-- agents read logs asynchronously whenever ready.
--
-- >>> import Agent.Fork
-- >>> import System.Directory
--

-- | Configuration for the pi agent channel.
--
-- Specifies the command to run, working directory, and paths to named pipes
-- for stdin, stdout, and stderr. Use 'defaultPiConfig' for sensible defaults.
data PiConfig = PiConfig
  { -- | Command to run (e.g., @"pi"@). May include arguments.
    processCommand :: String,
    -- | Working directory for process execution (e.g., @"."@)
    workDir :: FilePath,
    -- | Path to stdin FIFO (e.g., @"/tmp/pi-in"@)
    stdinPath :: FilePath,
    -- | Path to stdout log file (e.g., @"./log/pi-stdout.md"@)
    stdoutPath :: FilePath,
    -- | Path to stderr log file (e.g., @"./log/pi-stderr.md"@)
    stderrPath :: FilePath
  }
  deriving (Show, Eq)

-- | Default pi channel configuration.
--
-- Uses @"pi"@ as command, current directory as workdir, and @/tmp/pi-in@
-- for stdin with logs in @./log/pi-stdout.md@ and @./log/pi-stderr.md@.
--
-- Suitable for single-session agentic workflows. For multiple sessions,
-- vary the FIFO paths to avoid conflicts.
--
-- >>> processCommand defaultPiConfig
-- "pi"
--
-- >>> stdinPath defaultPiConfig
-- "/tmp/pi-in"
--
-- >>> workDir defaultPiConfig
-- "."
defaultPiConfig :: PiConfig
defaultPiConfig =
  PiConfig
    { processCommand = "pi",
      workDir = ".",
      stdinPath = "/tmp/pi-in",
      stdoutPath = "./log/pi-stdout.md",
      stderrPath = "./log/pi-stderr.md"
    }

-- | Ensure a FIFO exists, creating it if necessary.
--
-- Uses @mkfifo@ to create a named pipe at the given path if it does not
-- already exist. Safe to call repeatedly.
--
-- >>> ensureFifo "/tmp/test-agent-fifo"
-- >>> doesFileExist "/tmp/test-agent-fifo"
-- True
ensureFifo :: FilePath -> IO ()
ensureFifo path = do
  exists <- doesFileExist path
  unless exists $ do
    callProcess "mkfifo" [path]

-- | Reset the stdout and stderr log files for a channel.
--
-- Clears both log files so they start fresh. Useful for testing
-- to ensure each run has a clean slate.
--
-- >>> let cfg = defaultPiConfig
-- >>> resetChannel cfg
resetChannel :: PiConfig -> IO ()
resetChannel cfg = do
  writeFile (stdoutPath cfg) ""
  writeFile (stderrPath cfg) ""

-- | Spawn a pi agent session with named pipes.
--
-- Creates and wires named pipes for stdin, stdout, and stderr according to
-- the provided 'PiConfig'. The stdin FIFO is created if it does not exist;
-- stdout and stderr files are opened in append mode to preserve history.
--
-- All handles use 'NoBuffering' to ensure immediate output, critical for
-- agent interaction where delays impact query latency.
--
-- Returns a process handle. The caller is responsible for managing process
-- lifecycle (termination, cleanup). See 'System.Process' for handle operations.
--
-- = Example
--
-- Spawn a simple echo process and verify output was logged:
--
-- >>> let cfg = defaultPiConfig { processCommand = "echo hello" }
-- >>> resetChannel cfg
-- >>> ph <- piChannel cfg
-- >>> doesFileExist (stdinPath cfg)
-- True
-- >>> readFile (stdoutPath cfg)
-- "hello\n"
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
