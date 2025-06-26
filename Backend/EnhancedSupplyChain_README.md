# Enhanced Medicine Supply Chain Smart Contract

## Overview

The NewSupplyChain contract is an advanced ERC-721 based solution for medicine supply chain transparency and fraud detection. It provides complete traceability of medicines from manufacturer to end patient using blockchain technology.

## Key Features

### 🔐 Security Features
- **Merkle Tree Verification**: Only verified manufacturers can create medicine batches
- **EIP-712 Signatures**: Secure transfer authorization using structured data signing
- **Fraud Prevention**: Immutable records prevent tampering
- **QR Code Verification**: Each batch gets a unique QR code for end-user verification

### 📋 Supply Chain Tracking
- **Complete Transparency**: Track medicine from manufacturing to dispensing
- **Multi-Stage Process**: Manufacturer → Distributor → Wholesaler → Pharmacy → Patient
- **Real-time Status Updates**: Track current location and status of each batch
- **Expiry Management**: Automatic expiry validation

### 🏥 Stakeholder Management
- **Manufacturer Verification**: Merkle proof verification for authorized manufacturers
- **Role-based Access**: Different permissions for each supply chain participant
- **Signature Verification**: Pre-authorized transfers using digital signatures

## Contract Architecture

### Core Components

#### 1. BatchInfo Structure
```solidity
struct BatchInfo {
    uint256 tokenId;
    uint256 expiryDate;
    string medName;
    string manufacturerName;
    string distributorName;
    string wholesalerName;
    string pharmacistName;
    address manufacturerAddress;
    address distributorAddress;
    address wholesalerAddress;
    address pharmacistAddress;
    BatchStatus status;
    bool locked;
    uint256 createdAt;
    uint256 lastUpdated;
    string batchNumber;
    uint256 quantity;
    string qrCodeHash;
}
```

#### 2. Batch Status Enum
```solidity
enum BatchStatus { 
    Manufactured,
    InTransitToDistributor,
    AtDistributor,
    InTransitToWholesaler,
    AtWholesaler,
    InTransitToPharmacy,
    AtPharmacy,
    Dispensed
}
```

## Usage Guide

### 1. Deployment
```solidity
// Deploy with merkle root for manufacturer verification
constructor(bytes32 _merkleRoot)
```

### 2. Creating a Medicine Batch
```solidity
function createBatch(
    bytes32[] memory _merkleProof,
    string memory _medName,
    string memory _manufacturerName,
    string memory _batchNumber,
    uint256 _quantity,
    uint256 _expiryDate
) external
```

### 3. Transfer Process

#### Manufacturer to Distributor
```solidity
function transferToDistributor(
    address _manufacturerAddress,
    address _distributorAddress,
    uint256 _tokenId,
    string memory _distributorName,
    uint8 _v, bytes32 _r, bytes32 _s
) external
```

#### Confirm Receipt
```solidity
function confirmReceiptAtDistributor(uint256 _tokenId) external
```

### 4. QR Code Verification
```solidity
function verifyBatchByQR(uint256 _tokenId, string memory _qrCodeHash) external view returns (bool)
```

## Integration with Helper Functions

### Merkle Tree Management
Use `createMerkleTree.mjs` to generate merkle root and proofs:

```javascript
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

const allowlist = [
    ["0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D"],
    ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
    // ... more manufacturer addresses
];

const tree = StandardMerkleTree.of(allowlist, ["address"]);
```

### Signature Generation
Use `offChainSig.mjs` for EIP-712 signature generation:

```javascript
import { generateTransferSignature } from './offChainSig.mjs';

const signature = await generateTransferSignature(
    manufacturerSigner,
    manufacturerAddress,
    distributorAddress,
    tokenId,
    timestamp
);
```

## Events

The contract emits comprehensive events for tracking:

- `BatchCreated`: When a new batch is created
- `OwnershipTransferred`: When ownership changes between stakeholders
- `BatchStatusUpdated`: When batch status changes
- `QRCodeGenerated`: When QR code is generated
- `SignatureVerified`: When transfer signature is verified

## Security Considerations

### Access Control
- Only verified manufacturers can create batches
- Signature verification required for all transfers
- Owner-only functions for emergency controls

### Error Handling
- Custom errors for gas efficiency
- Comprehensive validation for all inputs
- Status verification for state transitions

### Emergency Features
- Batch locking/unlocking by contract owner
- Merkle root updates for manufacturer list changes

## Frontend Integration

### QR Code Scanning
End users can scan QR codes to verify medicine authenticity:

1. Scan QR code to get tokenId and hash
2. Call `verifyBatchByQR(tokenId, hash)`
3. If true, call `getSupplyChainHistory(tokenId)` to show complete journey

### Web3 Integration
```javascript
// Connect to contract
const contract = new ethers.Contract(contractAddress, abi, provider);

// Verify batch
const isValid = await contract.verifyBatchByQR(tokenId, qrHash);

// Get complete history
const history = await contract.getSupplyChainHistory(tokenId);
```

## Testing

### Unit Tests
Create comprehensive tests for:
- Batch creation with merkle verification
- Transfer processes with signature verification
- Status updates and validations
- QR code generation and verification

### Integration Tests
- End-to-end supply chain flow
- Multiple stakeholder interactions
- Error scenarios and edge cases

## Deployment Checklist

1. ✅ Generate merkle tree for authorized manufacturers
2. ✅ Deploy contract with merkle root
3. ✅ Verify contract on blockchain explorer
4. ✅ Set up frontend integration
5. ✅ Configure QR code generation system
6. ✅ Test complete supply chain flow

## Gas Optimization

- Custom errors instead of require strings
- Packed structs for storage efficiency
- Event-based logging for off-chain tracking
- Efficient signature verification

## Future Enhancements

- Multi-signature requirements for high-value batches
- Integration with IoT devices for temperature monitoring
- Regulatory compliance reporting
- Cross-chain compatibility
- Advanced analytics and reporting

## License

MIT License - See LICENSE file for details
