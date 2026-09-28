#ifndef NARTHEX_DESKTOP_SDK_ABI_H
#define NARTHEX_DESKTOP_SDK_ABI_H
#include "sophia_shell_files.h"
#include <string.h>

/* A C reader for values assigned by Nim. This catches field/union mismatches
 * that a same-language encode/decode round trip would hide. */
static inline int narthex_check_candidate(const struct sophia_sf_record *r) {
    const struct sophia_sf_descriptor_candidate *v = &r->value.descriptor_candidate;
    return r->header.kind == SOPHIA_SF_DESCRIPTOR_CANDIDATE &&
        r->header.epoch == 11 && r->header.submission == 12 && r->header.sequence == 0 &&
        v->transaction == 13 && v->connection_epoch == 11 &&
        v->snapshot_generation == 14 && v->candidate_generation == 15 &&
        v->output_id == 16 && v->visible == 1 && v->reservation_edge == 2 &&
        v->reservation_thickness == 24 && v->selected_slot == 7 && v->entry_count == 1 &&
        v->entries[0].slot == 7 && v->entries[0].generation == 17;
}
static inline void narthex_fill_activation(struct sophia_sf_record *r) {
    memset(r, 0, sizeof(*r));
    r->header.kind = SOPHIA_SF_DESCRIPTOR_ACTIVATION;
    r->header.epoch = 11;
    r->header.sequence = 12;
    r->value.descriptor_activation = (struct sophia_sf_descriptor_activation){
        .transaction = 13, .connection_epoch = 11, .candidate_generation = 14,
        .presentation_epoch = 15, .activation = 16, .action_token = 17,
        .action_issuer_epoch = 18, .action_issuer_revocation_epoch = 19,
        .action_recipient_epoch = 20, .action_target_slot = 21,
        .action_target_generation = 22};
}
static inline int narthex_check_reference(const struct sophia_sf_record *r) {
    const struct sophia_sf_reference_candidate *v = &r->value.reference_candidate;
    return v->transaction == 1 && v->connection_epoch == 2 && v->catalog_generation == 3 &&
        v->request_generation == 4 && v->candidate_generation == 5 && v->output_id == 6 &&
        v->visible == 1 && v->page == 2 && v->entry_count == 1 &&
        v->style.body_size == 14 && v->style.title_size == 20 && v->style.padding == 8 &&
        v->style.row_gap == 9 && v->style.key_gap == 10 && v->style.column_gap == 11 &&
        v->style.border == 1 && v->style.margin == 12 && v->style.columns == 2 &&
        v->style.colors[5] == 0x123456 && v->style.title.size == 5 &&
        memcmp(v->style.title.data, "title", 5) == 0 && v->rows_bytes == 204 && v->rows != NULL;
}
#endif
