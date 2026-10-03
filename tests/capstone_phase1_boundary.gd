extends RefCounted
## The historical filename is retained for checkpoint continuity. Phase2 now
## positively exercises every registered scene/art identity. The old11 list is
## only for explicit historical pixel comparisons whose baseline predates12.
const PHASE1_IDS: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt", "heting_consignee"]
const READY_IDS: Array[String] = ["story", "training", "sect_trial", "courtyard_practice", "sluice_scout", "sluice_boss", "archive_boss", "mist_scout", "mist_keeper", "heting_receipt", "heting_consignee", "capstone_authorizer"]
const CAPSTONE_ID: String = "capstone_authorizer"
