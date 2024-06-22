;; A generic manager that can be used by anyone to sell sub names
;; for any given owned name.

;; TODO: Minimal viable system, needs things commit-reveals, and so on.

(define-constant err-invalid-fqn (err u4000))
(define-constant err-not-owner (err u4001))
(define-constant err-no-prices (err u4002))

(define-map sub-name-ustx-prices (list 10 (string-utf8 40)) (list 40 uint))
(define-map sub-name-validity-periods (list 10 (string-utf8 40)) uint)

(define-read-only (get-fqn-owner (fqn (list 10 (string-utf8 40))))
	(contract-call? .cns-name get-owner-from-fqn fqn)
)

(define-read-only (get-fqn-ustx-prices (fqn (list 10 (string-utf8 40))))
	(map-get? sub-name-ustx-prices fqn)
)

(define-read-only (min (a uint) (b uint))
	(if (< a b) a b)
)

(define-read-only (get-sub-name-ustx-price (name (string-utf8 40)) (parent-fqn (list 10 (string-utf8 40))))
	(let (
		(name-prices (unwrap! (map-get? sub-name-ustx-prices parent-fqn) none))
		(name-len (len name))
		)
		(asserts! (> name-len u0) none)
		(element-at? name-prices (- (min (len name) (len name-prices)) u1))
	)
)

(define-read-only (get-sub-name-validity-period (fqn (list 10 (string-utf8 40))))
	(map-get? sub-name-validity-periods fqn)
)

(define-public (name-register (fqn (list 10 (string-utf8 40))) (recipient principal) (manager (optional principal)) (token-uri (optional (string-ascii 256))))
	(let (
		(parent-fqn (unwrap! (contract-call? .cns-name verify-fqn-get-parent-fqn fqn) err-invalid-fqn))
		(parent-owner (unwrap! (get-fqn-owner parent-fqn) err-invalid-fqn))
		(price (unwrap! (get-sub-name-ustx-price (unwrap! (element-at? fqn (- (len fqn) u1)) err-invalid-fqn) parent-fqn) err-no-prices))
	)
		(and (not (is-eq tx-sender parent-owner))
			(try! (stx-transfer? price tx-sender parent-owner))
		)
		(contract-call? .cns-name manager-name-register fqn tx-sender manager token-uri (map-get? sub-name-validity-periods parent-fqn) false)
	)
)

(define-read-only (tx-sender-is-owner (fqn (list 10 (string-utf8 40))))
	(ok (asserts! (is-eq (some tx-sender) (get-fqn-owner fqn)) err-not-owner))
)

(define-public (owner-set-registration-prices (fqn (list 10 (string-utf8 40))) (prices-in-ustx (optional (list 40 uint))))
	(begin
		(try! (tx-sender-is-owner fqn))
		(ok (match prices-in-ustx prices
			(map-set sub-name-ustx-prices fqn prices)
			(map-delete sub-name-ustx-prices fqn)
		))
	)
)

(define-public (owner-set-validity-period (fqn (list 10 (string-utf8 40))) (validity-period (optional uint)))
	(begin
		(try! (tx-sender-is-owner fqn))
		(ok (match validity-period period
			(map-set sub-name-validity-periods fqn period)
			(map-delete sub-name-validity-periods fqn)
		))
	)
)

(define-public (owner-change-manager (fqn (list 10 (string-utf8 40))) (new-manager principal))
	(begin
		(try! (tx-sender-is-owner fqn))
		(contract-call? .cns-name manager-update-manager fqn (some new-manager))
	)
)
