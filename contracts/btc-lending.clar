;; title: BTC Lending Protocol
;; summary: A decentralized lending platform built on Stacks.
;; description: This smart contract implements a BTC lending protocol on the Stacks blockchain. It allows users to deposit collateral, borrow against it, repay loans, and handle liquidations. The protocol includes governance functions to update fees and pause the protocol.

;; Constants

;; Protocol Parameters
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-COLLATERAL-RATIO u150)  ;; 150% minimum collateral ratio
(define-constant LIQUIDATION-THRESHOLD u130)  ;; 130% liquidation threshold
(define-constant LIQUIDATION-PENALTY u10)    ;; 10% penalty on liquidation
(define-constant PRICE-VALIDITY-PERIOD u3600) ;; 1 hour price validity
(define-constant MAX-FEE-PERCENTAGE u10)     ;; 10% maximum protocol fee

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-BELOW-MIN-COLLATERAL (err u103))
(define-constant ERR-LOAN-NOT-FOUND (err u104))
(define-constant ERR-LOAN-EXISTS (err u105))
(define-constant ERR-INVALID-LIQUIDATION (err u106))
(define-constant ERR-PRICE-EXPIRED (err u107))
(define-constant ERR-ZERO-AMOUNT (err u108))
(define-constant ERR-EXCEED-MAX-FEE (err u109))

;; Data Variables

;; Protocol State
(define-data-var protocol-paused bool false)
(define-data-var total-loans uint u0)
(define-data-var total-collateral uint u0)
(define-data-var protocol-fee-percentage uint u1) ;; 1% default fee

;; Price Oracle Data
(define-data-var btc-price-in-cents uint u0)
(define-data-var last-price-update uint u0)

;; Maps

;; Loan Data Structure
(define-map loans 
    { user: principal }
    {
        collateral-amount: uint,
        borrowed-amount: uint,
        last-update: uint,
        interest-rate: uint
    }
)

;; Balance Tracking
(define-map collateral-balances { user: principal } uint)
(define-map borrow-balances { user: principal } uint)

;; Private Functions

(define-private (validate-amount (amount uint)) 
    (begin
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        (ok true)))

(define-private (check-authorization)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok true)))

(define-private (check-protocol-active)
    (begin
        (asserts! (not (var-get protocol-paused)) ERR-NOT-AUTHORIZED)
        (ok true)))

;; Read-Only Functions

(define-read-only (get-loan (user principal))
    (map-get? loans { user: user }))

(define-read-only (get-collateral-balance (user principal))
    (default-to u0 (map-get? collateral-balances { user: user })))

(define-read-only (get-borrow-balance (user principal))
    (default-to u0 (map-get? borrow-balances { user: user })))

(define-read-only (get-current-collateral-ratio (user principal))
    (let (
        (loan (get-loan user))
    )
        (match loan
            loan-data (let (
                (collateral-value (* (get collateral-amount loan-data) (var-get btc-price-in-cents)))
                (borrowed-value (* (get borrowed-amount loan-data) u100))
            )
                (ok (/ (* collateral-value u100) borrowed-value)))
            (err u0))))

(define-read-only (is-price-valid)
    (< (- block-height (var-get last-price-update)) PRICE-VALIDITY-PERIOD))

(define-read-only (get-protocol-stats)
    {
        total-loans: (var-get total-loans),
        total-collateral: (var-get total-collateral),
        current-fee: (var-get protocol-fee-percentage),
        is-paused: (var-get protocol-paused)
    })

;; Public Functions

;; Price Oracle Functions
(define-public (update-btc-price (new-price-in-cents uint))
    (begin
        (try! (check-authorization))
        (try! (validate-amount new-price-in-cents))
        (var-set btc-price-in-cents new-price-in-cents)
        (var-set last-price-update block-height)
        (ok true)))

;; Core Lending Functions
(define-public (deposit-collateral (amount uint))
    (begin
        (try! (check-protocol-active))
        (try! (validate-amount amount))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set collateral-balances 
            { user: tx-sender }
            (+ (get-collateral-balance tx-sender) amount))
        
        (var-set total-collateral (+ (var-get total-collateral) amount))
        (ok true)))

(define-public (borrow (amount uint))
    (begin
        (try! (check-protocol-active))
        (try! (validate-amount amount))
        
        (let (
            (current-collateral (get-collateral-balance tx-sender))
            (current-loan (get-loan tx-sender))
            (collateral-value (* current-collateral (var-get btc-price-in-cents)))
        )
            (asserts! (is-price-valid) ERR-PRICE-EXPIRED)
            (asserts! (is-none current-loan) ERR-LOAN-EXISTS)
            (asserts! (>= (* collateral-value u100) (* amount MIN-COLLATERAL-RATIO)) ERR-BELOW-MIN-COLLATERAL)
            
            (map-set loans 
                { user: tx-sender }
                {
                    collateral-amount: current-collateral,
                    borrowed-amount: amount,
                    last-update: block-height,
                    interest-rate: u5 ;; 5% APR
                })
            
            (map-set borrow-balances 
                { user: tx-sender }
                (+ (get-borrow-balance tx-sender) amount))
            
            (var-set total-loans (+ (var-get total-loans) amount))
            (ok true))))

(define-public (repay-loan (amount uint))
    (begin
        (try! (check-protocol-active))
        (try! (validate-amount amount))
        
        (let (
            (loan (unwrap! (get-loan tx-sender) ERR-LOAN-NOT-FOUND))
            (current-borrowed (get borrowed-amount loan))
        )
            (asserts! (<= amount current-borrowed) ERR-INVALID-AMOUNT)
            
            (let (
                (blocks-elapsed (- block-height (get last-update loan)))
                (interest-amount (/ (* current-borrowed (get interest-rate loan) blocks-elapsed) (* u100 u144 u365)))
                (total-due (+ amount interest-amount))
            )
                (try! (stx-transfer? total-due tx-sender (as-contract tx-sender)))
                
                ;; Update loan state
                (if (is-eq amount current-borrowed)
                    (begin
                        (map-delete loans { user: tx-sender })
                        (map-delete borrow-balances { user: tx-sender }))
                    (begin
                        (map-set loans 
                            { user: tx-sender }
                            {
                                collateral-amount: (get collateral-amount loan),
                                borrowed-amount: (- current-borrowed amount),
                                last-update: block-height,
                                interest-rate: (get interest-rate loan)
                            })
                        (map-set borrow-balances 
                            { user: tx-sender }
                            (- (get-borrow-balance tx-sender) amount))))
                
                (var-set total-loans (- (var-get total-loans) amount))
                (ok true)))))

(define-public (liquidate (user principal))
    (begin
        (try! (check-protocol-active))
        
        (let (
            (loan (unwrap! (get-loan user) ERR-LOAN-NOT-FOUND))
            (collateral-ratio (unwrap! (get-current-collateral-ratio user) ERR-LOAN-NOT-FOUND))
        )
            (asserts! (is-price-valid) ERR-PRICE-EXPIRED)
            (asserts! (< collateral-ratio LIQUIDATION-THRESHOLD) ERR-INVALID-LIQUIDATION)
            
            (let (
                (collateral-amount (get collateral-amount loan))
                (borrowed-amount (get borrowed-amount loan))
                (liquidation-value (* borrowed-amount (+ u100 LIQUIDATION-PENALTY)))
                (remaining-collateral (- collateral-amount liquidation-value))
            )
                (try! (stx-transfer? liquidation-value tx-sender (as-contract tx-sender)))
                
                ;; Clear the loan
                (map-delete loans { user: user })
                (map-delete borrow-balances { user: user })
                
                ;; Update protocol state
                (var-set total-loans (- (var-get total-loans) borrowed-amount))
                (var-set total-collateral (- (var-get total-collateral) collateral-amount))
                
                ;; Return remaining collateral to user
                (if (> remaining-collateral u0)
                    (try! (as-contract (stx-transfer? remaining-collateral (as-contract tx-sender) user)))
                    true)
                
                (ok true)))))

;; Governance Functions

(define-public (update-protocol-fee (new-fee uint))
    (begin
        (try! (check-authorization))
        (asserts! (<= new-fee MAX-FEE-PERCENTAGE) ERR-EXCEED-MAX-FEE)
        (var-set protocol-fee-percentage new-fee)
        (ok true)))

(define-public (toggle-protocol-pause)
    (begin
        (try! (check-authorization))
        (var-set protocol-paused (not (var-get protocol-paused)))
        (ok true)))