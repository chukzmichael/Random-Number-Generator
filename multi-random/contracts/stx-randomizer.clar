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
(define-constant ERROR_METRICS_UPDATE_FAILED (err u110))
(define-constant ERROR_INVALID_ADDRESS (err u111))
(define-constant ERROR_INVALID_ENTROPY_VALUE (err u112))

;; Response type definitions
(define-constant SUCCESS_RESPONSE (ok true))

;; Configuration constants
(define-constant MAXIMUM_SEQUENCE_LENGTH u100)
(define-constant MINIMUM_ENTROPY_REQUIRED u10)
(define-constant COOLDOWN_BLOCKS u10)
(define-constant MAXIMUM_RANGE_SIZE u1000000)
(define-constant MAXIMUM_ENTROPY_VALUE u1000000)

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
    (if (is-eq tx-sender contract-deployment-owner)
        SUCCESS_RESPONSE
        ERROR_NOT_CONTRACT_OWNER)
)

(define-private (validate-generation-prerequisites)
    (begin
        (asserts! (not (var-get system-paused)) ERROR_SYSTEM_PAUSED)
        (asserts! (not (default-to false (map-get? blacklisted-addresses tx-sender))) ERROR_BLACKLISTED_ADDRESS)
        (asserts! (>= (var-get entropy-pool) MINIMUM_ENTROPY_REQUIRED) ERROR_INSUFFICIENT_ENTROPY)
        (asserts! (> block-height (+ (var-get last-generation-block) COOLDOWN_BLOCKS)) ERROR_COOLDOWN_PERIOD_ACTIVE)
        SUCCESS_RESPONSE
    )
)

(define-private (calculate-cryptographic-hash (random-input-value uint))
    (let (
        (input (concat 
            (unwrap-panic (to-consensus-buff? (var-get random-generation-sequence-number)))
            (unwrap-panic (to-consensus-buff? (xor 
                (xor 
                    random-input-value
                    block-height
                )
                (var-get entropy-pool)
            )))
        ))
        (hash-result (sha256 input))
        (truncated-hash (match (slice? hash-result u0 u16)
                slice-result (ok (unwrap-panic (as-max-len? slice-result u16)))
                (err "Failed to slice buffer")))
    )
    (buff-to-uint-be (unwrap-panic truncated-hash))
    )
)

(define-private (update-generation-metrics) 
    (begin
        (var-set total-generations (+ (var-get total-generations) u1))
        (var-set last-generation-block block-height)
        (map-set generation-timestamps (var-get total-generations) block-height)
        (map-set generation-results (var-get total-generations) (var-get latest-generated-random-number))
        (map-set user-generation-history tx-sender 
            (+ (default-to u0 (map-get? user-generation-history tx-sender)) u1))
        SUCCESS_RESPONSE
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
        (match (principal-destruct? address)
            success (ok (map-set blacklisted-addresses address true))
            error ERROR_INVALID_ADDRESS
        )
    )
)

(define-public (remove-from-blacklist (address principal))
    (begin
        (try! (verify-contract-owner-access))
        (match (principal-destruct? address)
            success (ok (map-delete blacklisted-addresses address))
            error ERROR_INVALID_ADDRESS
        )
    )
)

(define-public (add-entropy (entropy-value uint))
    (begin
        (asserts! (<= entropy-value MAXIMUM_ENTROPY_VALUE) ERROR_INVALID_ENTROPY_VALUE)
        (var-set entropy-pool (+ (var-get entropy-pool) entropy-value))
        SUCCESS_RESPONSE
    )
)

;; Random number generation functions
(define-public (generate-single-random-number)
    (let
        ((prerequisites-result (validate-generation-prerequisites)))
        (match prerequisites-result
            success-response 
                (let
                    ((random-value (calculate-cryptographic-hash (var-get cryptographic-seed-value))))
                    (begin
                        (var-set random-generation-sequence-number 
                            (+ (var-get random-generation-sequence-number) u1))
                        (var-set latest-generated-random-number random-value)
                        (var-set cryptographic-seed-value random-value)
                        (var-set entropy-pool (- (var-get entropy-pool) u1))
                        (ok random-value)))
            error-value (err error-value)
        )
    )
)

(define-public (generate-bounded-random-number (range-minimum-value uint) (range-maximum-value uint))
    (begin
        (asserts! (< range-minimum-value range-maximum-value) ERROR_NUMBER_RANGE_INVALID)
        (asserts! (<= (- range-maximum-value range-minimum-value) MAXIMUM_RANGE_SIZE) ERROR_NUMBER_RANGE_INVALID)
        (let ((random-value (try! (generate-single-random-number))))
            (ok (+ range-minimum-value (mod random-value (- range-maximum-value range-minimum-value))))
        )
    )
)

(define-public (generate-random-number-sequence (sequence-length uint))
    (begin
        (asserts! (> sequence-length u0) ERROR_GENERATION_PARAMETERS_INVALID)
        (asserts! (<= sequence-length MAXIMUM_SEQUENCE_LENGTH) ERROR_MAXIMUM_SEQUENCE_LENGTH_EXCEEDED)
        (try! (validate-generation-prerequisites))
        (let 
            (
                (result (fold accumulate-random-numbers 
                    (list u1 u2 u3 u4 u5) 
                    {acc: (list), len: u0, target: sequence-length}))
            )
            (ok (get acc result))
        )
    )
)

(define-public (generate-random-percentage)
    (let ((random-value (try! (generate-single-random-number))))
        (ok (mod random-value u101))
    )
)

(define-private (accumulate-random-numbers (sequence-position uint) (state {acc: (list 100 uint), len: uint, target: uint}))
    (let 
        (
            (random-value (unwrap-panic (generate-single-random-number)))
            (new-acc (unwrap! (as-max-len? (append (get acc state) random-value) u100) state))
            (new-len (+ (get len state) u1))
        )
        (if (< new-len (get target state))
            {acc: new-acc, len: new-len, target: (get target state)}
            state
        )
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