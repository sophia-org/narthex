#ifndef NARTHEX_DESKTOP_SDK_FFI_H
#define NARTHEX_DESKTOP_SDK_FFI_H
#include "sophia_shell_session.h"

/* Allocate the public, caller-owned SDK state without duplicating its private
 * fields in Nim. The caller zero-initializes it and retains ownership. */
static inline size_t narthex_ss_state_bytes(void) {
    return sizeof(struct sophia_ss);
}
/* Nim has no const-qualified pointer type. Copy public values instead of
 * discarding const. Rows/text still borrow SDK storage until consume or the
 * next object fetch; these helpers do not advance the session. */
static inline int narthex_ss_event(struct sophia_ss *session,
                                   struct sophia_sf_record *out) {
    const struct sophia_sf_record *record;
    int status = sophia_ss_event(session, &record);
    if (!status) *out = *record;
    return status;
}
static inline int narthex_ss_object_result(struct sophia_ss *session,
                                           struct sophia_sf_record *out) {
    const struct sophia_sf_record *record;
    int status = sophia_ss_object_result(session, &record);
    if (!status) *out = *record;
    return status;
}
static inline int narthex_ss_welcome(struct sophia_ss *session,
                                     struct sophia_sf_negotiated *out) {
    const struct sophia_sf_negotiated *welcome = sophia_ss_welcome(session);
    if (!welcome) return SOPHIA_9P_AGAIN;
    *out = *welcome;
    return 0;
}
#endif
