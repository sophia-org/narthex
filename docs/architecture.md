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

## Building A Desktop On Sophia

A third-party desktop needs two clients, not three. The bar is not a separate
role: it belongs to the shell. Sophia's `docs/compositor-graphics.md` states
this directly — "shell-owned" is an ownership rule, not a product description,
and it covers a small status bar and a full set of panels and decorations
alike. One shell client owns the bar, the switcher, notifications, and
indicators together, the way an integrated shell such as Noctalia bundles them.

| Component | Wire | Reference implementation |
| --- | --- | --- |
| Window manager | `sophia_wm_v1` | Hagia |
| Shell | `sophia_shell_v1` | Narthex |
| Display server | not written by the desktop author | Sophia and Engine |

### What Is Actually Implemented Today

`sophia_shell_v1` revision 1 is six messages and one capability,
`descriptor_switcher`. A shell sends an ordered list of window slots, each with
a label of at most 128 bytes, up to sixteen descriptors, and one selected slot.
Engine renders that list. There is no clock, tray, launcher, or arbitrary text.

Work-area reservation exists in Engine and in Narthex but is not yet in the
checked-in protocol specification, and Sophia's `docs/configuration.md` records
the remaining gap: the claim lives only for as long as the switcher is visible,
and a panel that persists independently of it needs a second shell role.

So a desktop author targeting the shell interface today is co-designing the
next revision, not writing against a stable surface. The window-manager
interface is the mature one: `sophia_wm_v1` revision 3 is frozen.
Sophia's `docs/sophia-shell-v1-direction.md` carries the direction work,
including a measured survey of what porting an existing full shell would cost.

### The Rendering Split Is About Pixel Blindness

Sophia does not divide work by component; it divides it by who may see pixels.
`docs/compositor-graphics.md` sets the rule in three parts:

| Visual form | Who executes it |
| --- | --- |
| A widget, artwork, or text that does not sample the scene | the shell rasterizes it and transfers bounded content-addressed content that Engine composites and caches |
| A recurring compositing operation such as a rounded rectangle, border, or shadow | Engine, because a shader is cheaper than uploading flat textures every frame |
| An operation needing compositor pixels, such as backdrop blur | Engine only, because the shell is pixel-blind and physically cannot perform it |

That last row is the Compositing Operator Rule: Engine admits a primitive only
when the client cannot execute it itself due to pixel blindness. A shell may
therefore draw a rich interface, but it can never read the screen. On Wayland
any layer-shell bar can capture the desktop; here it cannot, which is why an
effect like blur has to become an Engine primitive rather than a client trick.

### Screen Capture Goes Through Portals

Neither the window manager nor the shell can take a screenshot. Capture is a
portal decision, brokered and namespaced, in `crates/sophia-portal`
(`screen_capture.rs`, covering both screenshot and screen-recording modes with
an explicit pending decision). Sophia's `docs/wm-v1-freeze-surface.md` lists
screenshots and capture sessions as excluded from the window-manager interface
and separate by design, and `docs/sophia-shell-v1-direction.md` maps
`wlr-screencopy-unstable-v1` onto the portal rather than onto a shell
capability.

This is the same reasoning as the rendering split. A component that could
screenshot on demand would defeat pixel blindness, so capture is not a
capability either policy client holds; it is a brokered decision with an
identified requester.

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
