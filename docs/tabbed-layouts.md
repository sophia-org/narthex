# Persistent tab descriptors

`--serve` negotiates the revision-8 descriptor file profile and capability
`tab_groups`. The SDK fetches complete tab objects and dispatches switcher
snapshots, candidate outcomes and activation acknowledgements over 9P2000.L.
Proof modes use the same file transport with their smaller capability sets.

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
