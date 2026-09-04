# Persistent tab descriptors

`--serve` negotiates `sophia_shell_v1` revision 2 and capability `tab_groups`.
The event loop multiplexes persistent tab transfers, switcher snapshots,
candidate outcomes, and activation acknowledgements on the existing protected
shell connection. Proof modes retain the revision-1 handshake.

Tabs use recipient-local group and occurrence slots, opaque output handles,
selected slots, focus, sanitized descriptors, and opaque actions. Narthex never
receives geometry, SurfaceIds, icons, or raw application metadata. It confirms
the exact group order from a complete bounded transfer. Membership and selected
application remain Hagia policy, validated by Sophia.

A prepared candidate becomes remembered state only after Sophia reports it
presented. Stale presentation epochs and actions outside the presented
candidate are rejected. Tab state persists when the switcher opens or closes.

Sophia supplies the descriptor tier's fixed GPU-rendered chrome. Text can be
rasterized on the CPU on a cache miss before GPU composition. Narthex owns no
renderer or framebuffer. Rich raster content is outside this revision.
