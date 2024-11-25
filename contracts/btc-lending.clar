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