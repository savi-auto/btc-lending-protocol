# BTC Lending Protocol

A decentralized lending protocol built on the Stacks blockchain that enables users to deposit Bitcoin as collateral and borrow against it. This smart contract implements core lending functionality with liquidation mechanisms and protocol governance features.

## Overview

The BTC Lending Protocol allows users to:

- Deposit STX as collateral
- Borrow against their collateral
- Repay loans with interest
- Participate in liquidations of under-collateralized positions
- Track lending metrics and protocol health

## Key Features

### Collateral Management

- Minimum collateral ratio: 150%
- Liquidation threshold: 130%
- Liquidation penalty: 10%
- Real-time price feed integration with 1-hour validity period

### Interest and Fees

- Default protocol fee: 1%
- Maximum fee cap: 10%
- Fixed interest rate: 5% APR
- Interest calculated based on blocks elapsed

### Security Features

- Price oracle validity checks
- Protocol pause mechanism
- Owner-only administrative functions
- Balance and authorization validations

## Technical Specifications

### Constants

```clarity
MIN-COLLATERAL-RATIO: 150%
LIQUIDATION-THRESHOLD: 130%
LIQUIDATION-PENALTY: 10%
PRICE-VALIDITY-PERIOD: 3600 blocks (approximately 1 hour)
MAX-FEE-PERCENTAGE: 10%
```

### Error Codes

- `ERR-NOT-AUTHORIZED (100)`: Unauthorized access attempt
- `ERR-INSUFFICIENT-BALANCE (101)`: Insufficient balance for operation
- `ERR-INVALID-AMOUNT (102)`: Invalid amount specified
- `ERR-BELOW-MIN-COLLATERAL (103)`: Collateral ratio below minimum
- `ERR-LOAN-NOT-FOUND (104)`: Loan doesn't exist
- `ERR-LOAN-EXISTS (105)`: Loan already exists
- `ERR-INVALID-LIQUIDATION (106)`: Invalid liquidation attempt
- `ERR-PRICE-EXPIRED (107)`: Price feed data expired
- `ERR-ZERO-AMOUNT (108)`: Zero amount specified
- `ERR-EXCEED-MAX-FEE (109)`: Fee exceeds maximum allowed

## Core Functions

### User Functions

#### `deposit-collateral`

Deposits STX as collateral into the protocol.

```clarity
(deposit-collateral (amount uint))
```

#### `borrow`

Creates a loan against deposited collateral.

```clarity
(borrow (amount uint))
```

#### `repay-loan`

Repays an existing loan with interest.

```clarity
(repay-loan (amount uint))
```

#### `liquidate`

Liquidates an under-collateralized position.

```clarity
(liquidate (user principal))
```

### Read-Only Functions

#### `get-loan`

Retrieves loan details for a user.

```clarity
(get-loan (user principal))
```

#### `get-current-collateral-ratio`

Calculates current collateral ratio for a user.

```clarity
(get-current-collateral-ratio (user principal))
```

#### `get-protocol-stats`

Returns protocol-wide statistics.

```clarity
(get-protocol-stats)
```

### Administrative Functions

#### `update-btc-price`

Updates the BTC price oracle.

```clarity
(update-btc-price (new-price-in-cents uint))
```

#### `update-protocol-fee`

Updates the protocol fee percentage.

```clarity
(update-protocol-fee (new-fee uint))
```

#### `toggle-protocol-pause`

Toggles the protocol's pause state.

```clarity
(toggle-protocol-pause)
```

## Usage Examples

### Depositing Collateral

```clarity
;; Deposit 1000 STX as collateral
(contract-call? .btc-lending deposit-collateral u1000)
```

### Taking Out a Loan

```clarity
;; Borrow 500 STX against collateral
(contract-call? .btc-lending borrow u500)
```

### Repaying a Loan

```clarity
;; Repay 100 STX of the loan
(contract-call? .btc-lending repay-loan u100)
```

### Liquidating a Position

```clarity
;; Liquidate an under-collateralized position
(contract-call? .btc-lending liquidate 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Security Considerations

1. **Price Oracle Dependency**: The protocol relies on accurate and timely price feeds. Ensure the price oracle is reliable and frequently updated.

2. **Liquidation Risks**: Users should maintain healthy collateral ratios to avoid liquidation. The protocol enforces a 130% liquidation threshold.

3. **Interest Rate Risk**: The fixed 5% APR interest rate may need adjustment based on market conditions (requires contract upgrade).

4. **Administrative Controls**: The contract owner has significant control through administrative functions. Proper governance should be implemented.

## Contributing

The BTC Lending Protocol is open for community review and improvement suggestions. Please follow these steps to contribute:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description of changes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
