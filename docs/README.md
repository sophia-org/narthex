# Narthex Documentation

Narthex is a standalone Sophia shell policy client. These documents describe its
authority boundary and the engineering rules used when changing it.

## Architecture

- [Architecture](architecture.md): capability split, comparison with X11,
  Wayland, and macOS shells, and what Narthex does and does not own.

## Engineering

- [Style guide](style-guide.md): Nim conventions and boundary-code rules.
- [Data-oriented design](data-oriented-design.md): the types layer, canonical
  state, and unidirectional settlement. Enforced by
  `tools/check_data_oriented_layout.sh` via `nimble layout`.
