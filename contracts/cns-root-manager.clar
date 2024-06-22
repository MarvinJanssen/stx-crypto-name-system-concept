;; Root name manager, allows for everyone to create a
;; top level name (a "namespace"). Namespaces never
;; expire and have no owner. (This contract becomes the
;; owner.)

;; TODO: Minimal viable system, needs things like commit-reveals, and so on.

(define-constant contract-principal (as-contract tx-sender))
(define-constant proposal-duration u720)

(define-constant err-namespace-exists (err u3000))
(define-constant err-not-creator (err u3001))
(define-constant err-no-burn-cost (err u3002))
(define-constant err-unknown-proposal-or-expired (err u3003))
(define-constant err-already-signalled (err u3004))

(define-map namespace-creators (string-utf8 40) principal)
(define-map proposals uint { new-costs: (optional (list 40 uint)), new-vote-threshold: (optional uint), expiry: uint, accepted: bool })
(define-map proposal-signals { proposal-id: uint, namespace: (string-utf8 40)} bool)
(define-map proposal-signal-weight uint uint)

(define-data-var namespace-creator-vote-threshold uint (* (fold + (var-get namespace-ustx-burn-costs) u0) u10))
(define-data-var last-proposal-id uint u0)

(define-data-var namespace-ustx-burn-costs (list 40 uint) (list
	u100000000000
	u10000000000
	u1000000000
	u100000000
	u10000000
))

(define-read-only (get-namespace-creator (namespace (string-utf8 40)))
	(map-get? namespace-creators namespace)
)

(define-read-only (min (a uint) (b uint))
	(if (< a b) a b)
)

(define-read-only (get-namespace-burn-cost (namespace (string-utf8 40)))
	(let (
		(burn-costs (var-get namespace-ustx-burn-costs))
		(namespace-len (len namespace))
		)
		(asserts! (> namespace-len u0) none)
		(element-at? burn-costs (- (min (len namespace) (len burn-costs)) u1))
	)
)

(define-public (namespace-register (namespace (string-utf8 40)) (manager principal) (token-uri (optional (string-ascii 256))))
	(let ((burn-cost (unwrap! (get-namespace-burn-cost namespace) err-no-burn-cost)))
		(asserts! (map-insert namespace-creators namespace tx-sender) err-namespace-exists)
		(try! (stx-burn? burn-cost tx-sender))
		(contract-call? .cns-name manager-name-register (list namespace) contract-principal (some manager) token-uri none true)
	)
)

(define-read-only (caller-is-creator (namespace (string-utf8 40)))
	(ok (asserts! (is-eq (some contract-caller) (map-get? namespace-creators namespace)) err-not-creator))
)

(define-public (creator-transfer-vote-right (namespace (string-utf8 40)) (new-creator principal))
	(begin
		(try! (caller-is-creator namespace))
		(ok (map-set namespace-creators namespace new-creator))
	)
)

(define-public (propose-new-parameters (namespace (string-utf8 40)) (new-costs (optional (list 40 uint))) (new-vote-threshold (optional uint)))
	(let ((proposal-id (+ (var-get last-proposal-id) u1)))
		(try! (caller-is-creator namespace))
		(map-set proposals proposal-id { new-costs: new-costs, new-vote-threshold: new-vote-threshold, expiry: (+ block-height proposal-duration), accepted: false })
		(map-set proposal-signals { proposal-id: proposal-id, namespace: namespace } true)
		(map-set proposal-signal-weight proposal-id (default-to u0 (get-namespace-burn-cost namespace)))
		(var-set last-proposal-id proposal-id)
		(ok proposal-id)
	)
)

(define-public (signal-proposal (namespace (string-utf8 40)) (proposal-id uint))
	(let (
		(proposal (unwrap! (map-get? proposals proposal-id) err-unknown-proposal-or-expired))
		(new-weight (+ (default-to u0 (map-get? proposal-signal-weight proposal-id)) (default-to u0 (get-namespace-burn-cost namespace))))
		)
		(try! (caller-is-creator namespace))
		(asserts! (and (< (get expiry proposal) block-height) (not (get accepted proposal))) err-unknown-proposal-or-expired)
		(asserts! (map-insert proposal-signals { proposal-id: proposal-id, namespace: namespace } true) err-already-signalled)
		(map-set proposal-signal-weight proposal-id new-weight)
		(ok (and
			(>= new-weight (var-get namespace-creator-vote-threshold))
			(match (get new-costs proposal) inner (var-set namespace-ustx-burn-costs inner) true)
			(match (get new-vote-threshold proposal) inner (var-set namespace-creator-vote-threshold inner) true)
			(map-set proposals proposal-id (merge proposal { accepted: true }))
		))
	)
)
