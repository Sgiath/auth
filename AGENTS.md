# Sgiath Auth guide

## Project Overview

SgiathAuth is an opinionated authentication library for Phoenix LiveView applications using WorkOS AuthKit. It provides session/JWT-based authentication with refresh token support and first-class LiveView integration via `on_mount` hooks.

## Commands

```bash
mix test              # Run tests
mix check --fix       # Format code and fix issues
mix deps.get          # Install dependencies
```

## Development Environment

Uses Nix flakes (`flake.nix`) with direnv for reproducible development (Erlang 28, Elixir 1.19).

## Workflow

- whenever you discover a bug or improvement that is not directly included in current task file new Github issue using the gh issue create command so we can track it and prioritize it.
- before you declare you are done you MUST run mix check --fix and it must pass, fix any issues that could not be fixed automatically before returning back to user
