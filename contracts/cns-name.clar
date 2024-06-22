(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-constant err-not-owner (err u1000))
(define-constant err-unknown-name (err u2000))
(define-constant err-invalid-fqn (err u2001))
(define-constant err-name-expired (err u2002))
(define-constant err-unknown-parent-name (err u2003))
(define-constant err-name-taken (err u2005))
(define-constant err-not-manager (err u2006))
(define-constant err-manager-frozen (err u2006))
(define-constant err-cannot-delete-has-child-names (err u2007))
;; (define-constant err-owner-manager-conflict (err u2008))

(define-non-fungible-token cns-name uint)
(define-map cns-managers uint principal)
(define-map cns-manager-frozen uint bool)

(define-data-var last-token-id uint u0)
(define-map token-uris uint (string-ascii 256))
(define-map name-zonefile-hashes uint (buff 32))
(define-data-var fallback-token-uri (optional (string-ascii 256)) none)

(define-map name-to-token-id (list 10 (string-utf8 40)) uint)
(define-map token-id-to-name uint (list 10 (string-utf8 40)))
(define-map name-expiries uint uint)
(define-map child-name-count uint uint)

;; sip9 functions

(define-read-only (get-last-token-id)
	(ok (var-get last-token-id))
)

;; TODO: resolve token-uri up until a hit is found, fallback if no hit
(define-read-only (get-token-uri (token-id uint))
	(ok (match (map-get? token-uris token-id)
		uri (some uri)
		(var-get fallback-token-uri)
	))
)

(define-read-only (get-owner (token-id uint))
	(ok (nft-get-owner? cns-name token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
	(begin
		(asserts! (or (is-eq sender tx-sender) (is-eq sender contract-caller)) err-not-owner)
		(nft-transfer? cns-name token-id sender recipient)
	)
)

;; cns functions

(define-read-only (check-expired-chain (name (string-utf8 40)) (previous-fqn (list 10 (string-utf8 40))))
	(let (
		(next-fqn (unwrap-panic (as-max-len? (append previous-fqn name) u10)))
		(next-token-id (unwrap! (fqn-to-token-id next-fqn) previous-fqn))
		)
		(asserts! (not (token-id-is-expired next-token-id)) previous-fqn)
		next-fqn
	)
)

(define-read-only (resolve (fqn (list 10 (string-utf8 40))))
	(let ((token-id (unwrap! (fqn-to-token-id fqn) err-unknown-name)))
		(ok {
			fqn: fqn,
			token-id: token-id,
			owner: (unwrap! (get-owner-from-fqn fqn) err-unknown-name),
			expiry: (map-get? name-expiries token-id),
			expired: (not (is-eq (len (fold check-expired-chain fqn (list))) (len fqn))),
			zonefile-hash: (map-get? name-zonefile-hashes token-id),
			token-uri: (map-get? token-uris token-id),
			manager: (map-get? cns-managers token-id),
			manager-frozen: (default-to false (map-get? cns-manager-frozen token-id)),
			child-name-count: (default-to u0 (map-get? child-name-count token-id))
		})
	)
)

(define-read-only (token-id-to-fqn (token-id uint))
	(map-get? token-id-to-name token-id)
)

(define-read-only (fqn-to-token-id (fqn (list 10 (string-utf8 40))))
	(map-get? name-to-token-id fqn)
)

(define-read-only (token-id-is-expired (token-id uint))
	(match (map-get? name-expiries token-id) expiry
		(< expiry block-height)
		false
	)
)

(define-read-only (get-owner-from-fqn (fqn (list 10 (string-utf8 40))))
	(match (fqn-to-token-id fqn)
		token-id (nft-get-owner? cns-name token-id)
		none
	)
)

(define-read-only (get-explicit-manager-from-token-id (token-id uint))
	(map-get? cns-managers token-id)
)

(define-read-only (get-manager-from-token-id (token-id uint))
	(match (map-get? cns-managers token-id)
		manager (some manager)
		(nft-get-owner? cns-name token-id)
	)
)

(define-read-only (get-manager-from-fqn (fqn (list 10 (string-utf8 40))))
	(get-manager-from-token-id (try! (map-get? name-to-token-id fqn)))
)

(define-read-only (get-is-manager-frozen (token-id uint))
	(default-to false (map-get? cns-manager-frozen token-id))
)

(define-read-only (verify-name-in-fqn (name (string-utf8 40)) (previous bool))
	(and
		previous
		(> (len name) u0)
		(is-none (index-of? name u"."))
		;; TODO: filter other illigal characters
	)
)

(define-read-only (valid-fqn (fqn (list 10 (string-utf8 40))))
	(begin
		(asserts! (> (len fqn) u0) false)
		(fold verify-name-in-fqn fqn true)
	)
)

(define-read-only (verify-fqn-get-parent-fqn (fqn (list 10 (string-utf8 40))))
	(begin
		(asserts! (valid-fqn fqn) none)
		(slice? fqn u0 (- (len fqn) u1))
	)
)

(define-read-only (get-child-name-count (token-id uint))
	(default-to u0 (map-get? child-name-count token-id))
)

(define-public (update-zonefile-hash-by-token-id (token-id uint) (zonefile-hash (buff 32)))
	(let ((name-owner (unwrap! (nft-get-owner? cns-name token-id) err-unknown-name)))
		(asserts! (or (is-eq tx-sender name-owner) (is-eq contract-caller name-owner)) err-not-owner)
		(ok (map-set name-zonefile-hashes token-id zonefile-hash))
	)
)

(define-public (update-zonefile-hash-by-fqn (fqn (list 10 (string-utf8 40))) (zonefile-hash (buff 32)))
	(update-zonefile-hash-by-token-id (unwrap! (fqn-to-token-id fqn) err-unknown-name) zonefile-hash)
)

(define-read-only (caller-is-manager-of-fqn (fqn (list 10 (string-utf8 40))))
	(ok (asserts! (is-eq (some contract-caller) (get-manager-from-fqn fqn)) err-not-manager))
)

(define-read-only (caller-is-manager-of-token-id (token-id uint))
	(ok (asserts! (is-eq (some contract-caller) (get-manager-from-token-id token-id)) err-not-manager))
)

(define-public (manager-name-register (fqn (list 10 (string-utf8 40))) (recipient principal) (manager (optional principal)) (token-uri (optional (string-ascii 256))) (expiry-height (optional uint)) (freeze-manager bool))
	(let (
		(existing-token-id (fqn-to-token-id fqn))
		(token-id (match existing-token-id inner inner (+ (var-get last-token-id) u1)))
		(existing-owner (nft-get-owner? cns-name token-id))
		(parent-fqn (unwrap! (verify-fqn-get-parent-fqn fqn) err-invalid-fqn))
		(parent-token-id (unwrap! (map-get? name-to-token-id parent-fqn) err-unknown-parent-name))
		)
		(try! (caller-is-manager-of-fqn parent-fqn))
		(and
			(is-some existing-token-id)
			(asserts! (token-id-is-expired token-id) err-name-taken)
			(not (is-eq (some recipient) existing-owner))
			(is-some existing-owner)
			;; Transfer expired name to new owner
			(try! (nft-transfer? cns-name token-id (unwrap-panic existing-owner) recipient))
		)
		(map-set name-to-token-id fqn token-id)
		(map-set token-id-to-name token-id fqn)
		(match manager inner
			(and
				(not (is-eq recipient inner)) ;; Debating removing this line.
				(map-set cns-managers token-id inner)
				freeze-manager
				(map-set cns-manager-frozen token-id true)
			)
			true
		)
		(match token-uri inner (map-set token-uris token-id inner) true)
		(match expiry-height inner (map-set name-expiries token-id inner) true)
		(and
			(is-none existing-token-id)
			(map-set child-name-count parent-token-id (+ (default-to u0 (map-get? child-name-count parent-token-id)) u1))
			(try! (nft-mint? cns-name token-id recipient))
			(var-set last-token-id token-id)
		)
		(ok token-id)
	)
)

(define-public (manager-name-delete (fqn (list 10 (string-utf8 40))))
	(let (
		(token-id (unwrap! (map-get? name-to-token-id fqn) err-unknown-name))
		(parent-fqn (unwrap! (verify-fqn-get-parent-fqn fqn) err-invalid-fqn))
		(parent-token-id (unwrap! (map-get? name-to-token-id parent-fqn) err-unknown-parent-name))
		)
		(try! (caller-is-manager-of-fqn parent-fqn))
		(asserts! (is-eq (get-child-name-count token-id) u0) err-cannot-delete-has-child-names)
		(map-delete name-to-token-id fqn)
		(map-delete token-id-to-name token-id)
		(map-delete cns-managers token-id)
		(map-delete token-uris token-id)
		(map-set child-name-count parent-token-id (- (default-to u1 (map-get? child-name-count parent-token-id)) u1))
		(try! (nft-burn? cns-name token-id (unwrap! (nft-get-owner? cns-name token-id) err-unknown-name)))
		(ok token-id)
	)
)

(define-public (manager-name-transfer (fqn (list 10 (string-utf8 40))) (recipient principal))
	(let ((token-id (unwrap! (map-get? name-to-token-id fqn) err-unknown-name)))
		(try! (caller-is-manager-of-fqn (unwrap! (verify-fqn-get-parent-fqn fqn) err-invalid-fqn)))
		(try! (nft-transfer? cns-name token-id (unwrap! (nft-get-owner? cns-name token-id) err-unknown-name) recipient))
		(ok token-id)
	)
)

(define-public (manager-name-update (fqn (list 10 (string-utf8 40))) (new-expiry-height (optional (optional uint))) (new-token-uri (optional (optional (string-ascii 256)))))
	(let (
		(token-id (unwrap! (map-get? name-to-token-id fqn) err-unknown-name))
		(parent-fqn (unwrap! (verify-fqn-get-parent-fqn fqn) err-invalid-fqn))
		)
		(try! (caller-is-manager-of-fqn parent-fqn))
		(match new-expiry-height inner
			(match inner expiry
				(map-set name-expiries token-id expiry)
				(map-delete name-expiries token-id)
			)
			true
		)
		(match new-token-uri inner
			(match inner token-uri
				(map-set token-uris token-id token-uri)
				(map-delete token-uris token-id)
			)
			true
		)
		(ok token-id)
	)
)

(define-public (manager-update-manager (fqn (list 10 (string-utf8 40))) (new-manager (optional principal)))
	(let ((token-id (unwrap! (map-get? name-to-token-id fqn) err-unknown-name)))
		(try! (caller-is-manager-of-token-id token-id))
		(asserts! (get-is-manager-frozen token-id) err-manager-frozen)
		;; (asserts! (not (is-eq new-manager (map-get? cns-managers token-id))) err-owner-manager-conflict)
		(match new-manager
			inner (map-set cns-managers token-id inner)
			(map-delete cns-managers token-id) ;; Relinquish manager control to the token owner.
		)
		(ok true)
	)
)

(define-public (manager-freeze-manager (fqn (list 10 (string-utf8 40))))
	(let ((token-id (unwrap! (map-get? name-to-token-id fqn) err-unknown-name)))
		(try! (caller-is-manager-of-token-id token-id))
		(ok (map-set cns-manager-frozen token-id true))
	)
)

;; Launch root
(define-constant root-fqn (list))
(define-constant root-token-id u0)
(map-set token-id-to-name root-token-id root-fqn)
(map-set name-to-token-id root-fqn root-token-id)
(map-set cns-managers root-token-id .cns-root-manager)
(nft-mint? cns-name root-token-id .cns-root-manager)
