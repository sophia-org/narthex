# Pinned C desktop SDK

`source/` is an immutable archive of the signed SDK revision in `manifest.json`.
`upstream.commit` is the raw commit object, binding that revision to its source
Git tree. The manifest lists the SHA-256 of every source file. Authorization of
that commit is a separate signature review; the manifest is an integrity check.

Narthex's thin bindings compile only the nine_p, shell_files and shell_session
modules from this snapshot. They do not read a sibling SDK or Sophia checkout.
Descriptor-file support follows the accepted contract in
`source/spec/sophia-shell-descriptors.md`. This SDK revision is not yet published.

Make SDK changes in sophia-org/sophia-desktop-sdk-c, test and sign the commit,
then replace this archive and its manifest together. Never patch `source/`
in Narthex or substitute a moving branch for the recorded revision.
