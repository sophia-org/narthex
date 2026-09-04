# Narthex Architecture

Narthex is a shell policy client for the Sophia display server. It decides what
appears in a shell surface and what a selection means. It draws nothing.

## Why Narthex Is A Separate Process

Sophia splits a desktop into three processes with different capabilities:

| Process | Owns | Sees |
| --- | --- | --- |
| Sophia / Engine | scene, input, rendering, presentation, supervision | everything |
| Hagia | window policy: tags, views, layouts, focus | geometry and window facts |
| Narthex | shell policy: descriptors, reservations, activations | sanitized titles only |

Narthex never learns surface identifiers, coordinates, or icons. Sophia's own
conformance evidence records this as
`surface_ids_disclosed=0 coordinates_disclosed=0 icons_disclosed=0`.

Because Hagia and Narthex hold different capabilities, they cannot share an
address space. Merging them would either grant the switcher window-management
authority or reduce the window manager to what a shell is allowed to see. The
process boundary is the enforcement mechanism, not a packaging choice.

## How This Compares To Other Systems

| System | Scene owner | WM policy | Chrome | Processes |
| --- | --- | --- | --- | --- |
| dwm (X11) | X server | dwm, a client | dwm draws its own bar | 2 |
| xmonad (X11) | X server | xmonad, a client | xmobar, separate | 3 |
| Hyprland | itself | itself | itself and layer-shell clients | 1 |
| niri | itself | itself | itself and layer-shell clients | 1 |
| River and Triad | River | Triad, a client | Triad draws overlays; eww for the bar | 2-3 |
| Sophia, Hagia, Narthex | Sophia/Engine | Hagia, a client | Narthex decides, Engine draws | 3 |

Wayland collapsed a split that X11 always had. Under X11 the server owned the
display and the window manager was an ordinary client holding
`SubstructureRedirect`, which is why a window manager could be restarted without
losing the session. Hyprland and niri discard that: compositor, window manager,
and renderer are one binary. River re-established the split, and Sophia extends
it.

So Sophia is not a departure from Wayland so much as a return to the X11 process
model with confinement added.

### The Distinguishing Axis Is Rendering Authority

Process count is not what separates these systems. The question is who may draw.

- dwm is an X client, so nothing prevents it from drawing its own bar.
- Triad is a River client, but it still owns shm buffers and twelve render
  modules and draws its own chrome through layer shell.
- Hagia and Narthex draw nothing at all.

Under X11 any client can walk the window tree. Under Wayland a layer-shell
client draws whatever pixels it likes. Under Sophia the shell client receives
sanitized descriptors and returns an activation, and cannot draw. That
confinement is enforced by the protocol rather than requested by convention.

### macOS Reaches The Same Shape

macOS is the closest existing system. `WindowServer` owns the scene, compositing,
and input as one privileged process. `Dock.app` is a separate process that draws
the Dock, Mission Control, and the Command-Tab switcher; `ControlCenter` and
`SystemUIServer` are further separate shell processes. Applications cannot read
one another's windows, and screen recording requires explicit permission.

macOS therefore arrived independently at server separate from shell, with the
application switcher on the shell side. That is the same placement Narthex uses.

The instructive difference is that macOS has no Hagia. It offers no sanctioned
seam for third-party window-management policy, which is why tiling tools such as
yabai must disable System Integrity Protection to work at all. Apple separated
server from shell and then left no door for window policy. `sophia_wm_v1` is
that missing door, which is why this three-way split is a completed design
rather than an over-decomposition.

## What Narthex Owns

Narthex owns shell surface policy over the `sophia_shell_v1` wire:

- descriptor sets and their ordering;
- work-area reservations;
- activation acknowledgement and staleness rejection; and
- the private `ShellModel` that tracks what Sophia actually presented.

## What Narthex Does Not Own

Rendering, hit testing, physical input, window placement, tags, views, layouts,
focus policy, session launching, and process supervision. Window management
belongs to Hagia. Everything visual belongs to Sophia.

Narthex never grows a renderer. It may exercise the reservation wire and claim
work area, but Engine draws every pixel. A change that adds drawing, hit
testing, or a toolkit dependency is out of scope for this project.

## Settlement

Sophia launches Narthex in a separate protected domain, sends a complete
sanitized snapshot, and waits for exactly one bounded candidate. Narthex holds
no state that Sophia has not confirmed presenting: a rejected or superseded
candidate advances the generation and retries rather than becoming remembered
state. A fresh connection epoch discards everything.
