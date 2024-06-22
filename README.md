# Stacks Crypto Name System (CNS)

A naming system concept for the Stacks blockchain with the following properties:

- All names are SIP009 compliant NFTs.
- Each name has an owner.
- Each name has a manager (can be same as owner).
- Owners can change name properties like the zone file.
- Owners can transfer and trade names like any other NFT.
- Managers can register sub-names and change token URI and so on.
- Managers can transfer management to another manager or relinquish it to the
  owner of the name.
- Managers can freeze the manager setting to ensure management stability.
- Sub-names themselves are names, so all the above applies.

It creates an effective recursive NFT system where each NFT is a name that can
have zero or more sub names. Names are represented as a list of UTF-8 strings
on-chain and are each assigned a unique token ID.

Why "Crypto Name System"? Because CNS is more than just approaching the idea
of conventional DNS or other blockchain naming systems. It is a crypto system
first. Perhaps another apt name would be "NFT Name System".

# How to try it

Start a console session:

```clarity
;; Launch namespace "ryder", with tx-sender as the manager
(contract-call? .cns-root-manager namespace-register u"ryder" tx-sender none)

;; Register "community.ryder", set generic STX manager as the manager
(contract-call? .cns-name manager-name-register (list u"ryder" u"community") tx-sender (some .cns-generic-stx-manager) none none false)

;; Name owner sets prices to register sub names for names managed by the generic STX manager
(contract-call? .cns-generic-stx-manager owner-set-registration-prices (list u"ryder" u"community") (some (list u10000000 u10000000 u10000000 u10000000 u1000000)))

;; Switch tx-sender to someone else
::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5

;; Buy sub name "marvin.community.ryder"
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cns-generic-stx-manager name-register (list u"ryder" u"community" u"marvin") tx-sender none none)

;; Resolve "marvin.community.ryder"
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cns-name resolve (list u"ryder" u"community" u"marvin"))

;; Register a sub name for fun, no explicit manager so owner is implicit manager
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.cns-name manager-name-register (list u"ryder" u"community" u"marvin" u"hello") tx-sender none none none false)
```

# Open questions, problems, and todos

1. Hard to mass register many names at once.
2. Decide on whether to use `block-height` or `tenure-height`.
3. Which parameters for the root manager to use.
4. Commit-reveal mechanisms for th root manager and generic STX manager.
5. Can the owner and manager mapping be equal (explicit equal manager)?
6. Name manager voucher NFT contract to trade manager role.
7. How can CNS devs be paid? Do they need to be? Generic STX manager has dev
   fee system but how about the root manager?
8. How to deal with upper and lower case names?
