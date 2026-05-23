# surrealra1n modular architecture

This document describes the new modular runtime used by `surrealra1n_new.sh`.

## Entry points

- `surrealra1n.sh`
  - Original monolithic script kept for compatibility.
- `surrealra1n_new.sh`
  - New modular entry point.
  - This is the script that routes execution into modules.

## High-level execution flow

1. `surrealra1n_new.sh` starts.
2. Core bootstrap is loaded (`scripts/core/lib/bootstrap.sh`).
3. Auto-update checks are executed (`scripts/core/lib/auto_update.sh`).
4. Command dispatcher routes to a command module (`scripts/core/lib/dispatch.sh`).
5. Command module runs:
   - shared runtime init (`scripts/core/lib/runtime_context.sh`)
   - command-specific logic (`scripts/commands/<command>.sh`)

## Directory layout

- `scripts/core/lib/`
  - Shared framework-level modules:
    - `bootstrap.sh` - base environment setup.
    - `usage.sh` - unified CLI usage text.
    - `auto_update.sh` - update checks and pull/restart flow.
    - `dispatch.sh` - command-to-module routing.
    - `flows.sh` - reusable operational flows (pwndfu, shsh, key reads).
    - `command_helpers.sh` - argument normalization and flag helpers.
    - `runtime_context.sh` - runtime orchestrator + top-level error trap.

- `scripts/core/lib/runtime/`
  - Runtime internals split by responsibility:
    - `prepare_environment.sh` - dependency/bin setup and preflight.
    - `detect_device.sh` - device detection (normal/recovery/dfu).
    - `apply_profiles.sh` - device profile and variable assignment.

- `scripts/commands/`
  - One command per file, each containing command-specific logic:
    - `seprmvr64_ipsw.sh`
    - `seprmvr64_restore.sh`
    - `seprmvr64_boot.sh`
    - `make_custom_ipsw.sh`
    - `make_custom_ipsw_2.sh`
    - `restore.sh`
    - `downgrade.sh`
    - `boot.sh`
    - `fix_ios8.sh`

## Command module contract

Each command module should follow this pattern:

1. `source` required core libs.
2. Define `cmd_<name>()` function.
3. Define `main()` that:
   - calls `bootstrap_environment`
   - calls `init_runtime_context`
   - calls `cmd_<name> "$@"`
4. Call `main "$@"`.

## Shared helpers policy

When logic is reused by two or more commands:

- Put command-oriented helpers in `scripts/core/lib/flows.sh`.
- Put CLI/arg helpers in `scripts/core/lib/command_helpers.sh`.
- Keep command files focused on command-specific business logic.

## Adding a new command

1. Create `scripts/commands/<new_command>.sh`.
2. Implement `cmd_<new_command>()` using existing helpers.
3. Register the command in `scripts/core/lib/dispatch.sh`.
4. Update `scripts/core/lib/usage.sh`.
5. Validate with:
   - `bash -n scripts/core/lib/*.sh`
   - `bash -n scripts/core/lib/runtime/*.sh`
   - `bash -n scripts/commands/*.sh`
   - `./surrealra1n_new.sh --help`

