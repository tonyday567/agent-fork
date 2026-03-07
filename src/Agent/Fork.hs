-- |
-- Module      : Agent.Fork
-- Copyright   : (c) 2026 Tony Day
-- License     : BSD-2-Clause
-- Maintainer  : tonyday567@gmail.com
--
-- Agentic harness for the pi executable, providing Claude-style LLM interface
-- integration via named pipes.
--
-- = Overview
--
-- @Agent.Fork@ abstracts pi process management for agentic workflows. It uses
-- named pipes (FIFOs) to decouple process I/O, enabling reliable interaction
-- with console applications in stateful, asynchronous agent contexts.
--
-- = Usage
--
-- Spawn a pi session with default configuration:
--
-- > import Agent.Fork
-- > ph <- piChannel defaultPiConfig
--
-- Or use custom configuration:
--
-- > let cfg = PiConfig
-- >       { processCommand = "pi"
-- >       , workDir = "./project"
-- >       , stdinPath = "/tmp/pi-in"
-- >       , stdoutPath = "./pi-stdout.md"
-- >       , stderrPath = "./pi-stderr.md"
-- >       }
-- > ph <- piChannel cfg
--
-- = Design
--
-- Named pipes provide stable I/O decoupling:
--
-- - Agents write to stdin FIFO without blocking on console buffering
-- - Stdout and stderr are logged to files for inspection and history
-- - Process lifecycle is independent of I/O, supporting multiplexing
--
-- This pattern is proven robust from @grepl@ (cabal-repl harness).
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
ensureFifo :: FilePath -> IO ()
ensureFifo path = do
  exists <- doesFileExist path
  unless exists $ do
    callProcess "mkfifo" [path]

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
-- = Agentic Workflow Example
--
-- > cfg <- pure defaultPiConfig
-- > ph <- piChannel cfg
-- > -- Now agents can write to cfg's stdinPath and read from stdoutPath/stderrPath
-- > -- Output appears in logs for analysis and history
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
