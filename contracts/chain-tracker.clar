;; Chain Tracker Smart Contract
;; Comprehensive supply chain event tracking and coordination system

;; Constants for error handling
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-EVENT-NOT-FOUND (err u301))
(define-constant ERR-INVALID-PARTICIPANT (err u302))
(define-constant ERR-DUPLICATE-EVENT (err u303))
(define-constant ERR-INVALID-TIMESTAMP (err u304))
(define-constant ERR-INSUFFICIENT-VERIFICATION (err u305))
(define-constant ERR-INVALID-LOCATION (err u306))
(define-constant ERR-EVENT-LOCKED (err u307))

;; Contract owner for administrative functions
(define-constant CONTRACT-OWNER tx-sender)

;; Event status constants
(define-constant STATUS-PENDING "PENDING")
(define-constant STATUS-VERIFIED "VERIFIED")
(define-constant STATUS-DISPUTED "DISPUTED")
(define-constant STATUS-FINALIZED "FINALIZED")
(define-constant STATUS-CANCELLED "CANCELLED")

;; Supply chain event types
(define-constant EVENT-PRODUCTION "PRODUCTION")
(define-constant EVENT-QUALITY-CHECK "QUALITY_CHECK")
(define-constant EVENT-SHIPMENT "SHIPMENT")
(define-constant EVENT-CUSTOMS "CUSTOMS")
(define-constant EVENT-WAREHOUSE "WAREHOUSE")
(define-constant EVENT-RETAIL "RETAIL")
(define-constant EVENT-DELIVERY "DELIVERY")

;; Core supply chain events tracking
(define-map supply-chain-events
  { event-id: uint }
  {
    product-id: (string-ascii 64),
    event-type: (string-ascii 32),
    participant: principal,
    timestamp: uint,
    location: (string-utf8 128),
    status: (string-ascii 32),
    description: (string-utf8 512),
    metadata: (string-utf8 1024),
    verification-count: uint,
    is-locked: bool,
    created-by: principal,
    block-height: uint
  }
)

;; Event verification tracking
(define-map event-verifications
  { event-id: uint, verifier: principal }
  {
    verified-at: uint,
    verification-type: (string-ascii 32),
    signature: (optional (buff 65)),
    notes: (string-utf8 256),
    is-approved: bool,
    verifier-role: (string-ascii 32)
  }
)

;; Supply chain participants registry
(define-map chain-participants
  { participant: principal }
  {
    participant-type: (string-ascii 32),
    company-name: (string-utf8 128),
    location: (string-utf8 128),
    certifications: (list 10 (string-ascii 32)),
    authorized-at: uint,
    is-active: bool,
    reputation-score: uint,
    total-events-created: uint,
    total-verifications-made: uint
  }
)

;; Product journey tracking
(define-map product-journeys
  { product-id: (string-ascii 64) }
  {
    origin-participant: principal,
    current-participant: principal,
    destination-participant: (optional principal),
    journey-start: uint,
    expected-completion: (optional uint),
    total-events: uint,
    current-status: (string-ascii 32),
    journey-stage: (string-ascii 32),
    compliance-score: uint
  }
)

;; Location and logistics tracking
(define-map logistics-updates
  { update-id: uint }
  {
    event-id: uint,
    coordinates: (string-ascii 64),
    address: (string-utf8 256),
    temperature: (optional int),
    humidity: (optional uint),
    condition-notes: (string-utf8 256),
    transport-mode: (string-ascii 32),
    estimated-arrival: (optional uint),
    actual-arrival: (optional uint)
  }
)

;; Performance metrics and analytics
(define-map performance-metrics
  { participant: principal, period: uint }
  {
    events-processed: uint,
    average-processing-time: uint,
    compliance-rate: uint,
    error-count: uint,
    customer-satisfaction: uint,
    efficiency-score: uint
  }
)

;; Global counters and statistics
(define-data-var event-counter uint u0)
(define-data-var update-counter uint u0)
(define-data-var total-participants uint u0)
(define-data-var total-products-tracked uint u0)
(define-data-var system-version uint u1)

;; Event templates for standardization
(define-map event-templates
  { template-name: (string-ascii 32) }
  {
    description: (string-utf8 256),
    required-fields: (list 10 (string-ascii 32)),
    verification-requirements: uint,
    compliance-checks: (list 5 (string-ascii 32)),
    is-active: bool
  }
)

;; Initialize standard event templates
(map-set event-templates
  { template-name: "PRODUCTION_EVENT" }
  {
    description: u"Standard production event template",
    required-fields: (list "PRODUCT_ID" "BATCH_NUMBER" "QUANTITY" "QUALITY_SCORE" "OPERATOR"),
    verification-requirements: u2,
    compliance-checks: (list "SAFETY" "QUALITY" "ENVIRONMENTAL" "REGULATORY" "DOCUMENTATION"),
    is-active: true
  }
)

(map-set event-templates
  { template-name: "SHIPMENT_EVENT" }
  {
    description: u"Standard shipment event template",
    required-fields: (list "ORIGIN" "DESTINATION" "CARRIER" "TRACKING_NUMBER" "EXPECTED_DELIVERY"),
    verification-requirements: u3,
    compliance-checks: (list "DOCUMENTATION" "CUSTOMS" "INSURANCE" "HANDLING" "TEMPERATURE"),
    is-active: true
  }
)

;; Administrative functions
(define-public (register-participant
    (participant principal)
    (participant-type (string-ascii 32))
    (company-name (string-utf8 128))
    (location (string-utf8 128))
    (certifications (list 10 (string-ascii 32)))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set chain-participants
      { participant: participant }
      {
        participant-type: participant-type,
        company-name: company-name,
        location: location,
        certifications: certifications,
        authorized-at: block-height,
        is-active: true,
        reputation-score: u100,
        total-events-created: u0,
        total-verifications-made: u0
      }
    )
    (var-set total-participants (+ (var-get total-participants) u1))
    (ok true)
  )
)

(define-public (update-participant-status (participant principal) (new-status bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (match (map-get? chain-participants { participant: participant })
      participant-info (ok (map-set chain-participants
        { participant: participant }
        (merge participant-info { is-active: new-status })
      ))
      ERR-INVALID-PARTICIPANT
    )
  )
)

;; Core event creation function
(define-public (create-supply-chain-event
    (product-id (string-ascii 64))
    (event-type (string-ascii 32))
    (location (string-utf8 128))
    (description (string-utf8 512))
    (metadata (string-utf8 1024))
  )
  (let
    (
      (new-event-id (+ (var-get event-counter) u1))
      (participant-info (unwrap! (map-get? chain-participants { participant: tx-sender }) ERR-INVALID-PARTICIPANT))
      (current-height block-height)
    )
    (begin
      ;; Verify participant authorization
      (asserts! (get is-active participant-info) ERR-NOT-AUTHORIZED)
      
      ;; Create the event record
      (map-set supply-chain-events
        { event-id: new-event-id }
        {
          product-id: product-id,
          event-type: event-type,
          participant: tx-sender,
          timestamp: current-height,
          location: location,
          status: STATUS-PENDING,
          description: description,
          metadata: metadata,
          verification-count: u0,
          is-locked: false,
          created-by: tx-sender,
          block-height: current-height
        }
      )
      
      ;; Update counters and participant stats
      (var-set event-counter new-event-id)
      
      ;; Update participant statistics
      (map-set chain-participants
        { participant: tx-sender }
        (merge participant-info 
          {
            total-events-created: (+ (get total-events-created participant-info) u1),
            reputation-score: (if (> (+ (get reputation-score participant-info) u5) u1000) u1000 (+ (get reputation-score participant-info) u5))
          }
        )
      )
      
      ;; Initialize or update product journey
      (match (map-get? product-journeys { product-id: product-id })
        existing-journey 
          (map-set product-journeys
            { product-id: product-id }
            (merge existing-journey 
              {
                current-participant: tx-sender,
                total-events: (+ (get total-events existing-journey) u1),
                current-status: STATUS-PENDING
              }
            )
          )
        ;; Create new journey if doesn't exist
        (begin
          (map-set product-journeys
            { product-id: product-id }
            {
              origin-participant: tx-sender,
              current-participant: tx-sender,
              destination-participant: none,
              journey-start: current-height,
              expected-completion: none,
              total-events: u1,
              current-status: STATUS-PENDING,
              journey-stage: event-type,
              compliance-score: u100
            }
          )
          (var-set total-products-tracked (+ (var-get total-products-tracked) u1))
        )
      )
      
      (ok new-event-id)
    )
  )
)

;; Event verification function
(define-public (verify-event
    (event-id uint)
    (verification-type (string-ascii 32))
    (signature (optional (buff 65)))
    (notes (string-utf8 256))
    (is-approved bool)
  )
  (let
    (
      (event-data (unwrap! (map-get? supply-chain-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (verifier-info (unwrap! (map-get? chain-participants { participant: tx-sender }) ERR-INVALID-PARTICIPANT))
    )
    (begin
      ;; Verify participant authorization
      (asserts! (get is-active verifier-info) ERR-NOT-AUTHORIZED)
      (asserts! (not (get is-locked event-data)) ERR-EVENT-LOCKED)
      
      ;; Record verification
      (map-set event-verifications
        { event-id: event-id, verifier: tx-sender }
        {
          verified-at: block-height,
          verification-type: verification-type,
          signature: signature,
          notes: notes,
          is-approved: is-approved,
          verifier-role: (get participant-type verifier-info)
        }
      )
      
      ;; Update event verification count and status
      (let ((new-verification-count (+ (get verification-count event-data) u1)))
        (map-set supply-chain-events
          { event-id: event-id }
          (merge event-data 
            {
              verification-count: new-verification-count,
              status: (if (>= new-verification-count u3) STATUS-VERIFIED STATUS-PENDING)
            }
          )
        )
      )
      
      ;; Update verifier statistics
      (map-set chain-participants
        { participant: tx-sender }
        (merge verifier-info 
          {
            total-verifications-made: (+ (get total-verifications-made verifier-info) u1),
            reputation-score: (if is-approved 
              (if (> (+ (get reputation-score verifier-info) u3) u1000) u1000 (+ (get reputation-score verifier-info) u3))
              (if (< (get reputation-score verifier-info) u3) u0 (- (get reputation-score verifier-info) u3))
            )
          }
        )
      )
      
      (ok true)
    )
  )
)

;; Logistics update function
(define-public (update-logistics
    (event-id uint)
    (coordinates (string-ascii 64))
    (address (string-utf8 256))
    (temperature (optional int))
    (humidity (optional uint))
    (condition-notes (string-utf8 256))
    (transport-mode (string-ascii 32))
  )
  (let
    (
      (new-update-id (+ (var-get update-counter) u1))
      (event-data (unwrap! (map-get? supply-chain-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (participant-info (unwrap! (map-get? chain-participants { participant: tx-sender }) ERR-INVALID-PARTICIPANT))
    )
    (begin
      ;; Verify authorization
      (asserts! (or 
        (is-eq tx-sender (get participant event-data))
        (is-eq tx-sender (get created-by event-data))
      ) ERR-NOT-AUTHORIZED)
      
      ;; Create logistics update
      (map-set logistics-updates
        { update-id: new-update-id }
        {
          event-id: event-id,
          coordinates: coordinates,
          address: address,
          temperature: temperature,
          humidity: humidity,
          condition-notes: condition-notes,
          transport-mode: transport-mode,
          estimated-arrival: none,
          actual-arrival: none
        }
      )
      
      (var-set update-counter new-update-id)
      (ok new-update-id)
    )
  )
)

;; Batch event processing
(define-public (process-batch-events (events (list 20 { product-id: (string-ascii 64), event-type: (string-ascii 32) })))
  (let
    (
      (participant-info (unwrap! (map-get? chain-participants { participant: tx-sender }) ERR-INVALID-PARTICIPANT))
    )
    (begin
      (asserts! (get is-active participant-info) ERR-NOT-AUTHORIZED)
      (ok (map process-single-batch-event events))
    )
  )
)

(define-private (process-single-batch-event (event { product-id: (string-ascii 64), event-type: (string-ascii 32) }))
  (let
    (
      (new-event-id (+ (var-get event-counter) u1))
    )
    (begin
      (var-set event-counter new-event-id)
      { product-id: (get product-id event), event-id: new-event-id, status: "PROCESSED" }
    )
  )
)

;; Event status update function
(define-public (update-event-status (event-id uint) (new-status (string-ascii 32)) (reason (string-utf8 256)))
  (let
    (
      (event-data (unwrap! (map-get? supply-chain-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    (begin
      ;; Verify authorization (only event creator or contract owner)
      (asserts! (or 
        (is-eq tx-sender (get created-by event-data))
        (is-eq tx-sender CONTRACT-OWNER)
      ) ERR-NOT-AUTHORIZED)
      
      ;; Update event status
      (map-set supply-chain-events
        { event-id: event-id }
        (merge event-data { status: new-status })
      )
      
      (ok true)
    )
  )
)

;; Lock/unlock event for security
(define-public (lock-event (event-id uint))
  (let
    (
      (event-data (unwrap! (map-get? supply-chain-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    (begin
      (asserts! (or 
        (is-eq tx-sender (get created-by event-data))
        (is-eq tx-sender CONTRACT-OWNER)
      ) ERR-NOT-AUTHORIZED)
      
      (map-set supply-chain-events
        { event-id: event-id }
        (merge event-data { is-locked: true })
      )
      
      (ok true)
    )
  )
)

;; Read-only functions for querying data
(define-read-only (get-event-details (event-id uint))
  (map-get? supply-chain-events { event-id: event-id })
)

(define-read-only (get-event-verification (event-id uint) (verifier principal))
  (map-get? event-verifications { event-id: event-id, verifier: verifier })
)

(define-read-only (get-participant-info (participant principal))
  (map-get? chain-participants { participant: participant })
)

(define-read-only (get-product-journey (product-id (string-ascii 64)))
  (map-get? product-journeys { product-id: product-id })
)

(define-read-only (get-logistics-update (update-id uint))
  (map-get? logistics-updates { update-id: update-id })
)

(define-read-only (get-system-stats)
  {
    total-events: (var-get event-counter),
    total-participants: (var-get total-participants),
    total-products: (var-get total-products-tracked),
    total-logistics-updates: (var-get update-counter),
    system-version: (var-get system-version),
    contract-owner: CONTRACT-OWNER
  }
)

(define-read-only (get-participant-stats (participant principal))
  (match (map-get? chain-participants { participant: participant })
    participant-info 
      {
        events-created: (get total-events-created participant-info),
        verifications-made: (get total-verifications-made participant-info),
        reputation-score: (get reputation-score participant-info),
        is-active: (get is-active participant-info),
        participant-type: (get participant-type participant-info)
      }
    {
      events-created: u0,
      verifications-made: u0,
      reputation-score: u0,
      is-active: false,
      participant-type: "UNKNOWN"
    }
  )
)

;; Advanced analytics functions
(define-read-only (get-event-status-summary (product-id (string-ascii 64)))
  ;; Simplified implementation - would require iteration in practice
  (match (map-get? product-journeys { product-id: product-id })
    journey-info 
      {
        total-events: (get total-events journey-info),
        current-status: (get current-status journey-info),
        journey-stage: (get journey-stage journey-info),
        compliance-score: (get compliance-score journey-info)
      }
    {
      total-events: u0,
      current-status: "NOT_FOUND",
      journey-stage: "UNKNOWN",
      compliance-score: u0
    }
  )
)

(define-read-only (calculate-performance-score (participant principal))
  (match (map-get? chain-participants { participant: participant })
    participant-info 
      (let
        (
          (events-score (get total-events-created participant-info))
          (verification-score (get total-verifications-made participant-info))
          (reputation-score (get reputation-score participant-info))
        )
        (/ (+ events-score verification-score reputation-score) u3)
      )
    u0
  )
)

;; System maintenance functions
(define-public (update-system-version)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set system-version (+ (var-get system-version) u1))
    (ok (var-get system-version))
  )
)

(define-public (add-event-template
    (template-name (string-ascii 32))
    (description (string-utf8 256))
    (required-fields (list 10 (string-ascii 32)))
    (verification-requirements uint)
    (compliance-checks (list 5 (string-ascii 32)))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set event-templates
      { template-name: template-name }
      {
        description: description,
        required-fields: required-fields,
        verification-requirements: verification-requirements,
        compliance-checks: compliance-checks,
        is-active: true
      }
    ))
  )
)


;; title: chain-tracker
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

