;; Random Number Generator Contract
;; Enhanced version with additional features, security measures, and monitoring capabilities

;; Constants for contract ownership and error handling
(define-constant contract-deployment-owner tx-sender)
(define-constant ERROR_NOT_CONTRACT_OWNER (err u100))
(define-constant ERROR_NUMBER_RANGE_INVALID (err u101))
(define-constant ERROR_SEED_VALUE_ZERO (err u102))
(define-constant ERROR_GENERATION_PARAMETERS_INVALID (err u103))
(define-constant ERROR_SEQUENCE_OVERFLOW (err u104))
(define-constant ERROR_MAXIMUM_SEQUENCE_LENGTH_EXCEEDED (err u105))
(define-constant ERROR_COOLDOWN_PERIOD_ACTIVE (err u106))
(define-constant ERROR_BLACKLISTED_ADDRESS (err u107))
(define-constant ERROR_INSUFFICIENT_ENTROPY (err u108))
(define-constant ERROR_SYSTEM_PAUSED (err u109))

;; Configuration constants
(define-constant MAXIMUM_SEQUENCE_LENGTH u100)
(define-constant MINIMUM_ENTROPY_REQUIRED u10)
(define-constant COOLDOWN_BLOCKS u10)
(define-constant MAXIMUM_RANGE_SIZE u1000000)

;; Data variables for maintaining random number state
(define-data-var latest-generated-random-number uint u0)
(define-data-var random-generation-sequence-number uint u0)
(define-data-var cryptographic-seed-value uint u1)
(define-data-var entropy-pool uint u0)
(define-data-var system-paused bool false)
(define-data-var last-generation-block uint u0)
(define-data-var total-generations uint u0)
(define-data-var consecutive-uses-count uint u0)

;; Maps for advanced features
(define-map blacklisted-addresses principal bool)
(define-map user-generation-history principal uint)
(define-map generation-results uint uint)
(define-map generation-timestamps uint uint)

;; Read-only functions to access contract state
(define-read-only (get-latest-generated-random-number)
    (ok (var-get latest-generated-random-number))
)

(define-read-only (get-current-sequence-number)
    (ok (var-get random-generation-sequence-number))
)

(define-read-only (get-system-status)
    (ok {
        paused: (var-get system-paused),
        total-generations: (var-get total-generations),
        current-entropy: (var-get entropy-pool),
        last-generation: (var-get last-generation-block)
    })
)

(define-read-only (get-user-generation-count (user principal))
    (ok (default-to u0 (map-get? user-generation-history user)))
)

(define-read-only (is-address-blacklisted (address principal))
    (ok (default-to false (map-get? blacklisted-addresses address)))
)

;; Private administrative functions
(define-private (verify-contract-owner-access)
    (ok (asserts! (is-eq tx-sender contract-deployment-owner) ERROR_NOT_CONTRACT_OWNER))
)

(define-private (validate-generation-prerequisites)
    (begin
        (asserts! (not (var-get system-paused)) ERROR_SYSTEM_PAUSED)
        (asserts! (not (default-to false (map-get? blacklisted-addresses tx-sender))) ERROR_BLACKLISTED_ADDRESS)
        (asserts! (>= (var-get entropy-pool) MINIMUM_ENTROPY_REQUIRED) ERROR_INSUFFICIENT_ENTROPY)
        (asserts! (> block-height (+ (var-get last-generation-block) COOLDOWN_BLOCKS)) ERROR_COOLDOWN_PERIOD_ACTIVE)
        (ok true)
    )
)

(define-private (calculate-cryptographic-hash (random-input-value uint))
    (to-uint (sha256 (concat 
        (unwrap-panic (to-sequence (var-get random-generation-sequence-number)))
        (unwrap-panic (to-sequence random-input-value))
        (unwrap-panic (to-sequence block-height))
        (unwrap-panic (to-sequence (var-get entropy-pool)))
    )))
)

(define-private (update-generation-metrics)
    (begin
        (var-set total-generations (+ (var-get total-generations) u1))
        (var-set last-generation-block block-height)
        (map-set generation-timestamps (var-get total-generations) block-height)
        (map-set generation-results (var-get total-generations) (var-get latest-generated-random-number))
        (map-set user-generation-history tx-sender 
            (+ (default-to u0 (map-get? user-generation-history tx-sender)) u1))
        (ok true)
    )
)

;; Public administrative functions
(define-public (toggle-system-pause)
    (begin
        (try! (verify-contract-owner-access))
        (ok (var-set system-paused (not (var-get system-paused))))
    )
)

(define-public (add-to-blacklist (address principal))
    (begin
        (try! (verify-contract-owner-access))
        (ok (map-set blacklisted-addresses address true))
    )
)

(define-public (remove-from-blacklist (address principal))
    (begin
        (try! (verify-contract-owner-access))
        (ok (map-delete blacklisted-addresses address))
    )
)

(define-public (add-entropy (entropy-value uint))
    (begin
        (var-set entropy-pool (+ (var-get entropy-pool) entropy-value))
        (ok true)
    )
)

;; Random number generation functions
(define-public (generate-single-random-number)
    (begin
        (try! (validate-generation-prerequisites))
        (var-set random-generation-sequence-number (+ (var-get random-generation-sequence-number) u1))
        (var-set latest-generated-random-number (calculate-cryptographic-hash (var-get cryptographic-seed-value)))
        (var-set cryptographic-seed-value (var-get latest-generated-random-number))
        (var-set entropy-pool (- (var-get entropy-pool) u1))
        (try! (update-generation-metrics))
        (ok (var-get latest-generated-random-number))
    )
)

(define-public (generate-bounded-random-number (range-minimum-value uint) (range-maximum-value uint))
    (begin
        (asserts! (< range-minimum-value range-maximum-value) ERROR_NUMBER_RANGE_INVALID)
        (asserts! (<= (- range-maximum-value range-minimum-value) MAXIMUM_RANGE_SIZE) ERROR_NUMBER_RANGE_INVALID)
        (try! (generate-single-random-number))
        (ok (+ range-minimum-value (mod (var-get latest-generated-random-number) (- range-maximum-value range-minimum-value))))
    )
)

(define-public (generate-random-number-sequence (sequence-length uint))
    (begin
        (asserts! (> sequence-length u0) ERROR_GENERATION_PARAMETERS_INVALID)
        (asserts! (<= sequence-length MAXIMUM_SEQUENCE_LENGTH) ERROR_MAXIMUM_SEQUENCE_LENGTH_EXCEEDED)
        (try! (validate-generation-prerequisites))
        (let ((random-number-sequence (list)))
            (ok (unwrap-panic (fold accumulate-random-numbers 
                (list u1 u2 u3 u4 u5) 
                random-number-sequence)))
        )
    )
)

(define-public (generate-random-percentage)
    (begin
        (try! (generate-single-random-number))
        (ok (mod (var-get latest-generated-random-number) u101))
    )
)

(define-private (accumulate-random-numbers (sequence-position uint) (accumulated-random-numbers (list 100 uint)))
    (begin
        (try! (generate-single-random-number))
        (ok (unwrap-panic (as-max-len? 
            (append accumulated-random-numbers (var-get latest-generated-random-number))
            MAXIMUM_SEQUENCE_LENGTH
        )))
    )
)

;; Contract initialization with default values
(begin
    (var-set latest-generated-random-number u1)
    (var-set random-generation-sequence-number u0)
    (var-set cryptographic-seed-value u1)
    (var-set entropy-pool MINIMUM_ENTROPY_REQUIRED)
    (var-set system-paused false)
)