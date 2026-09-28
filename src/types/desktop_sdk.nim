## Public C SDK values only. Decoded pointers borrow the input record;
## copy semantic values before consuming an event or reusing object storage.
type
  SfText* {.
    importc: "struct sophia_sf_text", header: "sophia_shell_files_roles.h", bycopy
  .} = object
    data* {.importc: "data".}: ptr uint8
    size* {.importc: "size".}: uint16

  SfCatalogEntry* {.
    importc: "struct sophia_sf_catalog_entry",
    header: "sophia_shell_files_roles.h",
    bycopy
  .} = object
    slot* {.importc: "slot".}: uint16
    available* {.importc: "available".}: uint16
    label* {.importc: "label".}: SfText
    keywords* {.importc: "keywords".}: SfText
    identity* {.importc: "identity".}: SfText

  SfCatalog* {.
    importc: "struct sophia_sf_catalog", header: "sophia_shell_files_roles.h", bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    generation* {.importc: "generation".}: uint64
    entryCount* {.importc: "entry_count".}: uint16
    identitiesPresent* {.importc: "identities_present".}: uint16
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfNegotiate* {.
    importc: "struct sophia_sf_negotiate",
    header: "sophia_shell_files_content.h",
    bycopy
  .} = object
    minimumRevision* {.importc: "minimum_revision".}: uint16
    maximumRevision* {.importc: "maximum_revision".}: uint16
    requiredCapabilities* {.importc: "required_capabilities".}: uint64

  SfNegotiated* {.
    importc: "struct sophia_sf_negotiated",
    header: "sophia_shell_files_content.h",
    bycopy
  .} = object
    selectedRevision* {.importc: "selected_revision".}: uint16
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    capabilities* {.importc: "capabilities".}: uint64
    maxDescriptors* {.importc: "max_descriptors".}: uint16
    maxLabelBytes* {.importc: "max_label_bytes".}: uint16
    maxPendingActivations* {.importc: "max_pending_activations".}: uint16
    limitsPublished* {.importc: "limits_published".}: uint16

  SfObjectPublished* {.
    importc: "struct sophia_sf_object_published",
    header: "sophia_shell_files_content.h",
    bycopy
  .} = object
    objectKind* {.importc: "object_kind".}: uint16
    generation* {.importc: "generation".}: uint64
    qid* {.importc: "qid".}: uint64

  SfDescriptorOutcome* {.
    importc: "struct sophia_sf_descriptor_outcome",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    kind* {.importc: "kind".}: uint16

  SfDescriptorActivation* {.
    importc: "struct sophia_sf_descriptor_activation",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    activation* {.importc: "activation".}: uint64
    actionToken* {.importc: "action_token".}: uint64
    actionIssuerEpoch* {.importc: "action_issuer_epoch".}: uint64
    actionIssuerRevocationEpoch* {.importc: "action_issuer_revocation_epoch".}: uint64
    actionRecipientEpoch* {.importc: "action_recipient_epoch".}: uint64
    actionTargetSlot* {.importc: "action_target_slot".}: uint16
    actionTargetGeneration* {.importc: "action_target_generation".}: uint64

  SfReferenceRequest* {.
    importc: "struct sophia_sf_reference_request",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    catalogGeneration* {.importc: "catalog_generation".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    outputId* {.importc: "output_id".}: uint64
    outputGeneration* {.importc: "output_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    operation* {.importc: "operation".}: uint16

  SfReferenceOutcome* {.
    importc: "struct sophia_sf_reference_outcome",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    catalogGeneration* {.importc: "catalog_generation".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    page* {.importc: "page".}: uint16
    pages* {.importc: "pages".}: uint16
    kind* {.importc: "kind".}: uint16

  SfDescriptorLauncherRequest* {.
    importc: "struct sophia_sf_descriptor_launcher_request",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    request* {.importc: "request".}: SfReferenceRequest
    query* {.importc: "query".}: SfText

  SfDescriptorLauncherOutcome* {.
    importc: "struct sophia_sf_descriptor_launcher_outcome",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    kind* {.importc: "kind".}: uint16

  SfDescriptorLauncherActivation* {.
    importc: "struct sophia_sf_descriptor_launcher_activation",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    catalogGeneration* {.importc: "catalog_generation".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    presentationEpoch* {.importc: "presentation_epoch".}: uint64
    activation* {.importc: "activation".}: uint64
    slot* {.importc: "slot".}: uint16

  SfDescriptorLaunchOutcome* {.
    importc: "struct sophia_sf_descriptor_launch_outcome",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    grant* {.importc: "grant".}: SfDescriptorLauncherActivation
    status* {.importc: "status".}: uint16

  SfDescriptorActivationAck* {.
    importc: "struct sophia_sf_descriptor_activation_ack",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    activation* {.importc: "activation".}: uint64
    disposition* {.importc: "disposition".}: uint16

  SfDescriptorLauncherActivationAck* {.
    importc: "struct sophia_sf_descriptor_launcher_activation_ack",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    grant* {.importc: "grant".}: SfDescriptorLauncherActivation
    consumed* {.importc: "consumed".}: uint16

  SfDescriptorCandidateEntry* {.
    importc: "struct sophia_sf_descriptor_candidate_entry",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    slot* {.importc: "slot".}: uint16
    generation* {.importc: "generation".}: uint64

  SfDescriptorCandidate* {.
    importc: "struct sophia_sf_descriptor_candidate",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    snapshotGeneration* {.importc: "snapshot_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    outputId* {.importc: "output_id".}: uint64
    visible* {.importc: "visible".}: uint16
    reservationEdge* {.importc: "reservation_edge".}: uint16
    reservationThickness* {.importc: "reservation_thickness".}: uint16
    selectedSlot* {.importc: "selected_slot".}: uint16
    entryCount* {.importc: "entry_count".}: uint16
    entries* {.importc: "entries".}: array[16, SfDescriptorCandidateEntry]

  SfTabsCandidate* {.
    importc: "struct sophia_sf_tabs_candidate",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    snapshotGeneration* {.importc: "snapshot_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    groupCount* {.importc: "group_count".}: uint16
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfReferenceStyle* {.
    importc: "struct sophia_sf_reference_style",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    bodySize* {.importc: "body_size".}: uint16
    titleSize* {.importc: "title_size".}: uint16
    padding* {.importc: "padding".}: uint16
    rowGap* {.importc: "row_gap".}: uint16
    keyGap* {.importc: "key_gap".}: uint16
    columnGap* {.importc: "column_gap".}: uint16
    border* {.importc: "border".}: uint16
    margin* {.importc: "margin".}: uint16
    columns* {.importc: "columns".}: uint16
    colors* {.importc: "colors".}: array[6, uint32]
    title* {.importc: "title".}: SfText

  SfReferenceEntry* {.
    importc: "struct sophia_sf_reference_entry",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    slot* {.importc: "slot".}: uint16
    key* {.importc: "key".}: SfText
    label* {.importc: "label".}: SfText

  SfReferenceCandidate* {.
    importc: "struct sophia_sf_reference_candidate",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    catalogGeneration* {.importc: "catalog_generation".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    outputId* {.importc: "output_id".}: uint64
    visible* {.importc: "visible".}: uint16
    page* {.importc: "page".}: uint16
    entryCount* {.importc: "entry_count".}: uint16
    style* {.importc: "style".}: SfReferenceStyle
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfDescriptorLauncherCandidate* {.
    importc: "struct sophia_sf_descriptor_launcher_candidate",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    catalogGeneration* {.importc: "catalog_generation".}: uint64
    requestGeneration* {.importc: "request_generation".}: uint64
    candidateGeneration* {.importc: "candidate_generation".}: uint64
    outputId* {.importc: "output_id".}: uint64
    visible* {.importc: "visible".}: uint16
    selected* {.importc: "selected".}: uint16
    entryCount* {.importc: "entry_count".}: uint16
    fontSize* {.importc: "font_size".}: uint16
    colors* {.importc: "colors".}: array[4, uint32]
    entries* {.importc: "entries".}: array[32, uint16]

  SfDescriptorEntry* {.
    importc: "struct sophia_sf_descriptor_entry",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    slot* {.importc: "slot".}: uint16
    trustLevel* {.importc: "trust_level".}: uint16
    attention* {.importc: "attention".}: uint16
    labelPresent* {.importc: "label_present".}: uint16
    labelRedacted* {.importc: "label_redacted".}: uint16
    generation* {.importc: "generation".}: uint64
    actionToken* {.importc: "action_token".}: uint64
    actionIssuerEpoch* {.importc: "action_issuer_epoch".}: uint64
    actionIssuerRevocationEpoch* {.importc: "action_issuer_revocation_epoch".}: uint64
    actionRecipientEpoch* {.importc: "action_recipient_epoch".}: uint64
    actionTargetSlot* {.importc: "action_target_slot".}: uint16
    actionTargetGeneration* {.importc: "action_target_generation".}: uint64
    label* {.importc: "label".}: SfText

  SfDescriptors* {.
    importc: "struct sophia_sf_descriptors",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    snapshotGeneration* {.importc: "snapshot_generation".}: uint64
    outputId* {.importc: "output_id".}: uint64
    outputGeneration* {.importc: "output_generation".}: uint64
    brokerEpoch* {.importc: "broker_epoch".}: uint64
    brokerRevocationEpoch* {.importc: "broker_revocation_epoch".}: uint64
    descriptorCount* {.importc: "descriptor_count".}: uint16
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfTabGroup* {.
    importc: "struct sophia_sf_tab_group",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    groupSlot* {.importc: "group_slot".}: uint64
    outputId* {.importc: "output_id".}: uint64
    selectedSlot* {.importc: "selected_slot".}: uint16
    focused* {.importc: "focused".}: uint16
    entryCount* {.importc: "entry_count".}: uint16

  SfTabs* {.
    importc: "struct sophia_sf_tabs", header: "sophia_shell_files_descriptors.h", bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    generation* {.importc: "generation".}: uint64
    groupCount* {.importc: "group_count".}: uint16
    entryCount* {.importc: "entry_count".}: uint16
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfShortcutEntry* {.
    importc: "struct sophia_sf_shortcut_entry",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    slot* {.importc: "slot".}: uint16
    labelPresent* {.importc: "label_present".}: uint16
    groupPresent* {.importc: "group_present".}: uint16
    chord* {.importc: "chord".}: SfText
    action* {.importc: "action".}: SfText
    label* {.importc: "label".}: SfText
    group* {.importc: "group".}: SfText

  SfShortcuts* {.
    importc: "struct sophia_sf_shortcuts",
    header: "sophia_shell_files_descriptors.h",
    bycopy
  .} = object
    transaction* {.importc: "transaction".}: uint64
    connectionEpoch* {.importc: "connection_epoch".}: uint64
    generation* {.importc: "generation".}: uint64
    entryCount* {.importc: "entry_count".}: uint16
    rows* {.importc: "rows".}: ptr uint8
    rowsBytes* {.importc: "rows_bytes".}: csize_t

  SfHeader* {.
    importc: "struct sophia_sf_header", header: "sophia_shell_files.h", bycopy
  .} = object
    kind* {.importc: "kind".}: uint16
    epoch* {.importc: "epoch".}: uint64
    submission* {.importc: "submission".}: uint64
    sequence* {.importc: "sequence".}: uint64

  SfRecordValue* {.union, bycopy.} = object
    negotiated* {.importc: "negotiated".}: SfNegotiated
    objectPublished* {.importc: "object_published".}: SfObjectPublished
    negotiate* {.importc: "negotiate".}: SfNegotiate
    catalog* {.importc: "catalog".}: SfCatalog
    descriptorOutcome* {.importc: "descriptor_outcome".}: SfDescriptorOutcome
    descriptorActivation* {.importc: "descriptor_activation".}: SfDescriptorActivation
    referenceRequest* {.importc: "reference_request".}: SfReferenceRequest
    referenceOutcome* {.importc: "reference_outcome".}: SfReferenceOutcome
    descriptorLauncherRequest* {.importc: "descriptor_launcher_request".}:
      SfDescriptorLauncherRequest
    descriptorLauncherOutcome* {.importc: "descriptor_launcher_outcome".}:
      SfDescriptorLauncherOutcome
    descriptorLauncherActivation* {.importc: "descriptor_launcher_activation".}:
      SfDescriptorLauncherActivation
    descriptorLaunchOutcome* {.importc: "descriptor_launch_outcome".}:
      SfDescriptorLaunchOutcome
    descriptorActivationAck* {.importc: "descriptor_activation_ack".}:
      SfDescriptorActivationAck
    descriptorLauncherActivationAck* {.importc: "descriptor_launcher_activation_ack".}:
      SfDescriptorLauncherActivationAck
    descriptorCandidate* {.importc: "descriptor_candidate".}: SfDescriptorCandidate
    tabsCandidate* {.importc: "tabs_candidate".}: SfTabsCandidate
    referenceCandidate* {.importc: "reference_candidate".}: SfReferenceCandidate
    descriptorLauncherCandidate* {.importc: "descriptor_launcher_candidate".}:
      SfDescriptorLauncherCandidate
    descriptors* {.importc: "descriptors".}: SfDescriptors
    tabs* {.importc: "tabs".}: SfTabs
    shortcuts* {.importc: "shortcuts".}: SfShortcuts

  SfRecord* {.
    importc: "struct sophia_sf_record", header: "sophia_shell_files.h", bycopy
  .} = object
    header*: SfHeader
    value*: SfRecordValue

  Ss* {.
    importc: "struct sophia_ss", header: "sophia_shell_session.h", incompleteStruct
  .} = object

  SfProfile* {.
    importc: "enum sophia_sf_profile",
    header: "sophia_shell_files_client.h",
    size: sizeof(cint),
    pure
  .} = enum
    bar
    launcher
    dock
    descriptor

  SsState* {.
    importc: "enum sophia_ss_state",
    header: "sophia_shell_session.h",
    size: sizeof(cint),
    pure
  .} = enum
    negotiating
    ready
    refusedNegotiation
    stale
    closed
    failed

  SsOutcome* {.
    importc: "enum sophia_ss_outcome",
    header: "sophia_shell_session.h",
    size: sizeof(cint),
    pure
  .} = enum
    unavailable
    admittedLocal
    inFlight
    submitted
    refused
    droppedUnsent
    unknownDisconnected

  SsConfig* {.
    importc: "struct sophia_ss_config", header: "sophia_shell_session.h", bycopy
  .} = object
    offer*: SfNegotiate
    profile*: SfProfile
    msize*: uint32
    queueSlots* {.importc: "queue_slots".}: uint16
    queueBytes* {.importc: "queue_bytes".}: csize_t
    objectStorage* {.importc: "object_storage".}: pointer
    objectCapacity* {.importc: "object_capacity".}: csize_t

  SsObligations* {.
    importc: "struct sophia_ss_obligations", header: "sophia_shell_session.h", bycopy
  .} = object
    consumed*, acked*: uint64
    ackLimit* {.importc: "ack_limit".}: uint64
    ackDueMs* {.importc: "ack_due_ms".}: uint64
    objects*, blocked*: uint8
