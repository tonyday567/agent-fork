# agent-fork

[![Hackage](https://img.shields.io/hackage/v/agent-fork.svg)](https://hackage.haskell.org/package/agent-fork)
[![Build Status](https://github.com/tonyday567/agent-fork/workflows/haskell-ci/badge.svg)](https://github.com/tonyday567/agent-fork/actions?query=workflow%3Ahaskell-ci)

## Overview

`agent-fork` provides a harness for wrapping the `pi` executable with a Claude-style LLM interface. It is designed as an agentic experimental platform, enabling interactive code exploration, type wrangling, and collaborative problem-solving between agents and Haskell systems.

The library abstracts `pi` process management via **named pipes** (FIFOs), a design pattern proven robust for handling unpredictable console applications. This approach decouples input/output streams, allowing agents to query and interact with `pi` sessions reliably in stateful, asynchronous workflows.

## Architecture

### Core Components

- **PiConfig** — Configuration for `pi` process execution, specifying command, working directory, and named pipe paths.
- **piChannel** — Spawns a `pi` process with stdin/stdout/stderr wired to named pipes, returning a process handle.
- **Named Pipe Pattern** — Decouples process I/O, enabling reliable interaction with console applications in agentic contexts.

### Design Rationale

Named pipes provide a stable interface for agent workflows:
- Agents write queries to stdin FIFO without blocking on console buffering.
- Stdout and stderr are logged to markdown files, preserving interaction history for agent analysis.
- Process lifecycle is independent of I/O, allowing agents to multiplex queries across sessions.

This pattern is borrowed from `grepl` (a cabal-repl harness with proven success in agentic code exploration).

## Usage

### Basic Setup

```haskell
import Agent.Fork

-- Spawn a pi session with default configuration
let cfg = defaultPiConfig
ph <- piChannel cfg
```

### Custom Configuration

```haskell
let cfg = PiConfig
      { processCommand = "pi"
      , workDir = "./my-project"
      , stdinPath = "/tmp/pi-agent-in"
      , stdoutPath = "./pi-agent-stdout.md"
      , stderrPath = "./pi-agent-stderr.md"
      }
ph <- piChannel cfg
```

### Agent Workflows

```haskell
-- Write a query to the stdin FIFO (non-blocking)
writeFile "/tmp/pi-agent-in" "type SomeType\n"

-- Read logged output asynchronously
stdout <- readFile "./pi-agent-stdout.md"
stderr <- readFile "./pi-agent-stderr.md"

-- Analyze results, branch on outcome, re-query as needed
```

## Integration with Agentic Systems

`agent-fork` is designed for systems where:
- Agents coordinate multiple tool interactions
- Interaction history must be preserved for auditing and learning
- Queries are dynamic and driven by prior results
- Process reliability matters more than console ergonomics

The named pipe design makes it ideal for:
- **Type exploration** — Query `pi` types, parse results, refine queries
- **Code generation** — Generate code snippets, test them, iterate
- **Session multiplexing** — Run multiple `pi` instances for parallel exploration

## Documentation

See [Agent.Fork](https://hackage.haskell.org/package/agent-fork/docs/Agent-Fork.html) for detailed API documentation, including configuration options and process management patterns.

## Related Work

- **grepl** — A similar harness for cabal-repl sessions, demonstrating the named-pipe pattern
- **pi** — The underlying Claude-style LLM interface and query tool
