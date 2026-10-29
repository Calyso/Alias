# Changelog

All notable changes to Alias are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.0.5] - 2026-10-29
### Added
- Addon version shown in the window title ("Alias | 2.0.5").

## [2.0.4] - 2026-10-29
### Fixed
- Alias names that shadow the client's built-in chat commands (`/g`, `/s`, `/p`, `/w`, `/r`, `/e`, `/guild`, and the like) are now rejected with a clear error instead of silently replacing the real command.
- Purely numeric names (`/1` through `/25`) are rejected as alias names.

## [2.0.3] - 2026-10-29
### Fixed
- Command names already owned by other addons (for example `/simc`) are now detected and rejected when adding an alias.

## [2.0.2] - 2026-10-29
### Added
- A clear error when the alias name is already taken by the client, another addon, or the `/alias` manager itself.
- A warning on login for saved aliases whose names have since been taken, instead of silently doing nothing.
### Changed
- An alias is saved only after it has actually registered.

## [2.0.1] - 2026-10-28
### Added
- Complete rewrite of the addon: alias management window, minimap button, and EllesmereUI skinning support.
### Fixed
- Crash when dragging the minimap button.
