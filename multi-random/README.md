# Random Number Generator Smart Contract

## About
This smart contract implements a secure and versatile random number generator on the Stacks blockchain. It provides various methods for generating random numbers with additional features for security, monitoring, and administrative control.

## Features

### Random Number Generation
- Single random number generation
- Bounded random number generation within a specified range
- Random number sequence generation
- Random percentage generation (0-100)

### Security Features
- Entropy pool management
- Cooldown periods between generations
- Address blacklisting
- System pause functionality
- Owner-only administrative functions
- Cryptographic hashing for randomness

### Monitoring and Metrics
- Generation history tracking
- User activity monitoring
- Timestamp recording
- System status monitoring

## Constants

### System Limits
- Maximum Sequence Length: 100
- Minimum Entropy Required: 10
- Cooldown Blocks: 10
- Maximum Range Size: 1,000,000

### Error Codes
- 100: Not Contract Owner
- 101: Invalid Number Range
- 102: Invalid Seed Value
- 103: Invalid Generation Parameters
- 104: Sequence Overflow
- 105: Maximum Sequence Length Exceeded
- 106: Cooldown Period Active
- 107: Blacklisted Address
- 108: Insufficient Entropy
- 109: System Paused

## Public Functions

### Random Number Generation
```clarity
(generate-single-random-number)
(generate-bounded-random-number (range-minimum-value uint) (range-maximum-value uint))
(generate-random-number-sequence (sequence-length uint))
(generate-random-percentage)
```

### Administrative Functions
```clarity
(toggle-system-pause)
(add-to-blacklist (address principal))
(remove-from-blacklist (address principal))
(add-entropy (entropy-value uint))
```

### Read-Only Functions
```clarity
(get-latest-generated-random-number)
(get-current-sequence-number)
(get-system-status)
(get-user-generation-count (user principal))
(is-address-blacklisted (address principal))
```

## Usage Examples

### Generate a Single Random Number
```clarity
(contract-call? .random-generator generate-single-random-number)
```

### Generate a Number Between 1 and 10
```clarity
(contract-call? .random-generator generate-bounded-random-number u1 u10)
```

### Generate a Random Percentage
```clarity
(contract-call? .random-generator generate-random-percentage)
```

## Security Considerations

1. **Entropy Management**: The contract requires a minimum entropy level for operation. Users can add entropy through the `add-entropy` function.

2. **Cooldown Periods**: A cooldown period of 10 blocks is enforced between generations to prevent rapid successive calls.

3. **Blacklisting**: Malicious addresses can be blacklisted by the contract owner.

4. **System Pause**: The contract can be paused in case of emergencies.

5. **Limited Range**: Random number generation within ranges is limited to prevent overflow attacks.

## State Management

The contract maintains several state variables:
- Latest generated random number
- Sequence number
- Cryptographic seed value
- Entropy pool level
- System pause status
- Generation history
- User activity metrics

## Administrative Controls

The contract owner has access to:
- Toggle system pause
- Manage blacklisted addresses
- Monitor system status
- Track user activity

## Best Practices

1. Always check return values for errors
2. Monitor entropy levels regularly
3. Use bounded random number generation when possible
4. Implement appropriate cooldown periods for your use case
5. Regularly monitor blacklisted addresses