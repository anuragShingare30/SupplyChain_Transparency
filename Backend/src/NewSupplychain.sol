// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NewSupplyChain contract
 * @author anurag shingare

 * @dev The task and flow of application to follow:
    1. createMedicineBatch -> check for validate user stored in tree -> only eligible user will able to createBatch.
    2. transfer ownership to distributor -> verify the signature -> generate sig. off-chain -> verify it on-chain
 */

contract NewSupplyChain is ERC721,Ownable,EIP712 {
    using ECDSA for bytes32;


    // Custom errors for better gas efficiency
    error NewSupplyChain_InvalidProof();
    error NewSupplyChain_InvalidSignature_ByDistributor();
    error NewSupplyChain_InvalidSignature_ByRetailer();
    error NewSupplyChain_InvalidSignature_ByWholesaler();
    error NewSupplyChain_InvalidSignature_ByPharmacists();
    error NewSupplyChain_ZeroAddressNotAllowed();
    error NewSupplyChain_AlreadyPresent_CheckForMaliciousActivity();
    error NewSupplyChain_TokenDoesNotExist();
    error NewSupplyChain_InvalidBatchStatus();
    error NewSupplyChain_NotAuthorized();
    error NewSupplyChain_BatchExpired();
    error NewSupplyChain_BatchLocked();


    // Enhanced enum with more descriptive status
    enum BatchStatus { 
        Manufactured,        // Initial state after batch creation
        InTransitToDistributor,
        AtDistributor,
        InTransitToWholesaler,
        AtWholesaler,
        InTransitToPharmacy,
        AtPharmacy,
        Dispensed           // Final state when medicine is given to patient
    }

    // Enhanced batch information structure
    struct BatchInfo {
        uint256 tokenId;
        uint256 expiryDate;           // Changed to uint256 for better date handling
        string medName;               // Changed to string for better readability
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
        string batchNumber;           // Unique batch identifier
        uint256 quantity;             // Number of units in the batch
        string qrCodeHash;            // Hash for QR code verification
    }

    // EIP-712 Type Hash for signature verification
    bytes32 private constant TRANSFER_TYPEHASH = keccak256(
        "Transfer(address from,address to,uint256 tokenId,uint256 timestamp)"
    );

    mapping(uint256 => BatchInfo) public s_batches;
    mapping(address => bool) public s_authorizedManufacturers;
    mapping(uint256 => string) public s_qrCodes;
    
    // State variables
    uint256 private s_tokenCounter;
    bytes32 public s_merkleRoot;  // Store merkle root for manufacturer verification
    // bytes32[] private _merkleProof = [
    //     bytes32(0x59856afbe8900ffcd32b8de545b9b5c0128ecda7289ff898b2ea8dc62b3f9a07),
    //     bytes32(0xf6949786c44ce4b9916e434fcdb9ff65f5c1c50d4fd00c0c34ce124acb64a922),
    //     bytes32(0x079d80974de7a6a2b5658681d9914e122e80917d90056c1f9d6b3ad021733efc)
    // ];


    // Enhanced events for better tracking
    event BatchCreated(
        uint256 indexed tokenId,
        address indexed manufacturer,
        string medName,
        string batchNumber,
        uint256 quantity,
        uint256 expiryDate
    );
    event OwnershipTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        BatchStatus newStatus,
        uint256 timestamp
    );
    event BatchStatusUpdated(uint256 indexed tokenId, BatchStatus status);
    event QRCodeGenerated(uint256 indexed tokenId, string qrCodeHash);
    event BatchLocked(uint256 indexed tokenId, address lockedBy);
    event BatchUnlocked(uint256 indexed tokenId, address unlockedBy);
    event ManufacturerVerified(address indexed manufacturer, bytes32 merkleRoot);
    event SignatureVerified(
        address indexed signer,
        address indexed recipient,
        uint256 indexed tokenId,
        BatchStatus newStatus
    );

    // Enhanced modifiers
    modifier zeroAddressNotAllowed(address _addr) {
        if (_addr == address(0)) {
            revert NewSupplyChain_ZeroAddressNotAllowed();
        }
        _;
    }

    modifier tokenExists(uint256 _tokenId) {
        if (_tokenId == 0 || _tokenId >= s_tokenCounter) {
            revert NewSupplyChain_TokenDoesNotExist();
        }
        _;
    }

    modifier notExpired(uint256 _tokenId) {
        if (block.timestamp > s_batches[_tokenId].expiryDate) {
            revert NewSupplyChain_BatchExpired();
        }
        _;
    }

    modifier notLocked(uint256 _tokenId) {
        if (s_batches[_tokenId].locked) {
            revert NewSupplyChain_BatchLocked();
        }
        _;
    }


    constructor(bytes32 _merkleRoot)
        ERC721("MedicineSupplyChain", "MSC")
        Ownable(msg.sender)
        EIP712("MedicineSupplyChain", "1.0")
    {
        s_tokenCounter = 1;  // Start from 1 for better UX
        s_merkleRoot = _merkleRoot;
    }

    /**
     * @notice Creates a new medicine batch (NFT) with comprehensive tracking
     * @dev Only verified manufacturers can create batches using merkle proof verification
     * @param _merkleProof Merkle proof to verify manufacturer eligibility
     * @param _medName Name of the medicine
     * @param _manufacturerName Name of the manufacturing company
     * @param _batchNumber Unique batch identifier
     * @param _quantity Number of units in this batch
     * @param _expiryDate Expiry timestamp of the medicine
     */
    // @audit function can be vulnerable for re-rentracy attack
    function createBatch(
        bytes32[] memory _merkleProof,
        string memory _medName,
        string memory _manufacturerName,
        string memory _batchNumber,
        uint256 _quantity,
        uint256 _expiryDate
    ) external zeroAddressNotAllowed(msg.sender) {
        
        // Validate inputs
        require(bytes(_medName).length > 0, "Medicine name cannot be empty");
        require(bytes(_manufacturerName).length > 0, "Manufacturer name cannot be empty");
        require(bytes(_batchNumber).length > 0, "Batch number cannot be empty");
        require(_quantity > 0, "Quantity must be greater than 0");
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");
        
        // Verify manufacturer using merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(_merkleProof, s_merkleRoot, leaf)) {
            revert NewSupplyChain_InvalidProof();
        }

        uint256 currentTokenId = s_tokenCounter;
        
        // Mint NFT to manufacturer
        _safeMint(msg.sender, currentTokenId);

        // Generate QR code hash for this batch
        string memory qrCodeHash = _generateQRCodeHash(currentTokenId, _batchNumber, msg.sender);

        // Create batch information
        BatchInfo memory newBatch = BatchInfo({
            tokenId: currentTokenId,
            expiryDate: _expiryDate,
            medName: _medName,
            manufacturerName: _manufacturerName,
            distributorName: "",
            wholesalerName: "",
            pharmacistName: "",
            manufacturerAddress: msg.sender,
            distributorAddress: address(0),
            wholesalerAddress: address(0),
            pharmacistAddress: address(0),
            status: BatchStatus.Manufactured,
            locked: false,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            batchNumber: _batchNumber,
            quantity: _quantity,
            qrCodeHash: qrCodeHash
        });

        s_batches[currentTokenId] = newBatch;
        s_qrCodes[currentTokenId] = qrCodeHash;
        s_authorizedManufacturers[msg.sender] = true;

        emit BatchCreated(currentTokenId, msg.sender, _medName, _batchNumber, _quantity, _expiryDate);
        emit QRCodeGenerated(currentTokenId, qrCodeHash);
        emit ManufacturerVerified(msg.sender, s_merkleRoot);

        s_tokenCounter++;
    }


    /**
     * @notice Transfers batch from manufacturer to distributor with signature verification
     * @dev Uses EIP-712 signature verification for secure transfer authorization
     * @param _manufacturerAddress Address of the manufacturer who signed the transfer
     * @param _distributorAddress Address of the distributor receiving the batch
     * @param _tokenId Token ID of the batch being transferred
     * @param _distributorName Name of the distributor
     * @param _v Signature parameter v
     * @param _r Signature parameter r
     * @param _s Signature parameter s
     */
    function transferToDistributor(
        address _manufacturerAddress,
        address _distributorAddress,
        uint256 _tokenId,
        string memory _distributorName,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external 
        tokenExists(_tokenId) 
        notExpired(_tokenId) 
        notLocked(_tokenId)
        zeroAddressNotAllowed(_distributorAddress) 
    {
        BatchInfo storage batch = s_batches[_tokenId];
        
        // Verify current status
        if (batch.status != BatchStatus.Manufactured) {
            revert NewSupplyChain_InvalidBatchStatus();
        }
        
        // Verify manufacturer is the current owner
        if (ownerOf(_tokenId) != _manufacturerAddress) {
            revert NewSupplyChain_NotAuthorized();
        }

        // Create EIP-712 structured data hash
        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                _manufacturerAddress,
                _distributorAddress,
                _tokenId,
                block.timestamp
            )
        );
        
        bytes32 digest = _hashTypedDataV4(structHash);
        
        // Verify signature
        if (!_isValidSignature(_manufacturerAddress, digest, _v, _r, _s)) {
            revert NewSupplyChain_InvalidSignature_ByDistributor();
        }

        // Update batch information
        batch.distributorName = _distributorName;
        batch.distributorAddress = _distributorAddress;
        batch.status = BatchStatus.InTransitToDistributor;
        batch.lastUpdated = block.timestamp;

        // Transfer NFT ownership
        _transfer(_manufacturerAddress, _distributorAddress, _tokenId);

        emit OwnershipTransferred(_tokenId, _manufacturerAddress, _distributorAddress, BatchStatus.InTransitToDistributor, block.timestamp);
        emit SignatureVerified(_manufacturerAddress, _distributorAddress, _tokenId, BatchStatus.InTransitToDistributor);
    }


    /**
     * @notice Confirms receipt at distributor and updates status
     * @param _tokenId Token ID of the batch
     */
    function confirmReceiptAtDistributor(uint256 _tokenId) external tokenExists(_tokenId) {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (ownerOf(_tokenId) != msg.sender) {
            revert NewSupplyChain_NotAuthorized();
        }
        
        if (batch.status != BatchStatus.InTransitToDistributor) {
            revert NewSupplyChain_InvalidBatchStatus();
        }

        batch.status = BatchStatus.AtDistributor;
        batch.lastUpdated = block.timestamp;

        emit BatchStatusUpdated(_tokenId, BatchStatus.AtDistributor);
    }

    /**
     * @notice Transfers batch from distributor to wholesaler
     */
    function transferToWholesaler(
        address _distributorAddress,
        address _wholesalerAddress,
        uint256 _tokenId,
        string memory _wholesalerName,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external 
        tokenExists(_tokenId) 
        notExpired(_tokenId) 
        notLocked(_tokenId)
        zeroAddressNotAllowed(_wholesalerAddress) 
    {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (batch.status != BatchStatus.AtDistributor) {
            revert NewSupplyChain_InvalidBatchStatus();
        }
        
        if (ownerOf(_tokenId) != _distributorAddress) {
            revert NewSupplyChain_NotAuthorized();
        }

        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                _distributorAddress,
                _wholesalerAddress,
                _tokenId,
                block.timestamp
            )
        );
        
        bytes32 digest = _hashTypedDataV4(structHash);
        
        if (!_isValidSignature(_distributorAddress, digest, _v, _r, _s)) {
            revert NewSupplyChain_InvalidSignature_ByWholesaler();
        }

        batch.wholesalerName = _wholesalerName;
        batch.wholesalerAddress = _wholesalerAddress;
        batch.status = BatchStatus.InTransitToWholesaler;
        batch.lastUpdated = block.timestamp;

        _transfer(_distributorAddress, _wholesalerAddress, _tokenId);

        emit OwnershipTransferred(_tokenId, _distributorAddress, _wholesalerAddress, BatchStatus.InTransitToWholesaler, block.timestamp);
        emit SignatureVerified(_distributorAddress, _wholesalerAddress, _tokenId, BatchStatus.InTransitToWholesaler);
    }


    /**
     * @notice Confirms receipt at wholesaler
     */
    function confirmReceiptAtWholesaler(uint256 _tokenId) external tokenExists(_tokenId) {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (ownerOf(_tokenId) != msg.sender) {
            revert NewSupplyChain_NotAuthorized();
        }
        
        if (batch.status != BatchStatus.InTransitToWholesaler) {
            revert NewSupplyChain_InvalidBatchStatus();
        }

        batch.status = BatchStatus.AtWholesaler;
        batch.lastUpdated = block.timestamp;

        emit BatchStatusUpdated(_tokenId, BatchStatus.AtWholesaler);
    }

    /**
     * @notice Transfers batch from wholesaler to pharmacy
     */
    function transferToPharmacy(
        address _wholesalerAddress,
        address _pharmacyAddress,
        uint256 _tokenId,
        string memory _pharmacistName,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external 
        tokenExists(_tokenId) 
        notExpired(_tokenId) 
        notLocked(_tokenId)
        zeroAddressNotAllowed(_pharmacyAddress) 
    {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (batch.status != BatchStatus.AtWholesaler) {
            revert NewSupplyChain_InvalidBatchStatus();
        }
        
        if (ownerOf(_tokenId) != _wholesalerAddress) {
            revert NewSupplyChain_NotAuthorized();
        }

        bytes32 structHash = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                _wholesalerAddress,
                _pharmacyAddress,
                _tokenId,
                block.timestamp
            )
        );
        
        bytes32 digest = _hashTypedDataV4(structHash);
        
        if (!_isValidSignature(_wholesalerAddress, digest, _v, _r, _s)) {
            revert NewSupplyChain_InvalidSignature_ByPharmacists();
        }

        batch.pharmacistName = _pharmacistName;
        batch.pharmacistAddress = _pharmacyAddress;
        batch.status = BatchStatus.InTransitToPharmacy;
        batch.lastUpdated = block.timestamp;

        _transfer(_wholesalerAddress, _pharmacyAddress, _tokenId);

        emit OwnershipTransferred(_tokenId, _wholesalerAddress, _pharmacyAddress, BatchStatus.InTransitToPharmacy, block.timestamp);
        emit SignatureVerified(_wholesalerAddress, _pharmacyAddress, _tokenId, BatchStatus.InTransitToPharmacy);
    }

    /**
     * @notice Confirms receipt at pharmacy
     */
    function confirmReceiptAtPharmacy(uint256 _tokenId) external tokenExists(_tokenId) {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (ownerOf(_tokenId) != msg.sender) {
            revert NewSupplyChain_NotAuthorized();
        }
        
        if (batch.status != BatchStatus.InTransitToPharmacy) {
            revert NewSupplyChain_InvalidBatchStatus();
        }

        batch.status = BatchStatus.AtPharmacy;
        batch.lastUpdated = block.timestamp;

        emit BatchStatusUpdated(_tokenId, BatchStatus.AtPharmacy);
    }

    /**
     * @notice Marks medicine as dispensed to patient
     */
    function dispenseMedicine(uint256 _tokenId) external tokenExists(_tokenId) {
        BatchInfo storage batch = s_batches[_tokenId];
        
        if (ownerOf(_tokenId) != msg.sender) {
            revert NewSupplyChain_NotAuthorized();
        }
        
        if (batch.status != BatchStatus.AtPharmacy) {
            revert NewSupplyChain_InvalidBatchStatus();
        }

        batch.status = BatchStatus.Dispensed;
        batch.lastUpdated = block.timestamp;

        emit BatchStatusUpdated(_tokenId, BatchStatus.Dispensed);
    }


    // UTILITY FUNCTIONS
    
    /**
     * @notice Locks a batch to prevent transfers (emergency function)
     */
    function lockBatch(uint256 _tokenId) external onlyOwner tokenExists(_tokenId) {
        s_batches[_tokenId].locked = true;
        emit BatchLocked(_tokenId, msg.sender);
    }

    /**
     * @notice Unlocks a batch to allow transfers
     */
    function unlockBatch(uint256 _tokenId) external onlyOwner tokenExists(_tokenId) {
        s_batches[_tokenId].locked = false;
        emit BatchUnlocked(_tokenId, msg.sender);
    }

    /**
     * @notice Updates the merkle root for manufacturer verification
     */
    function updateMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        s_merkleRoot = _newMerkleRoot;
    }

    // INTERNAL FUNCTIONS
    
    /**
     * @notice Validates signature using EIP-712 standard
     */
    function _isValidSignature(
        address _signer,
        bytes32 _digest,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (bool) {
        address recoveredSigner = ECDSA.recover(_digest, _v, _r, _s);
        return recoveredSigner == _signer;
    }

    /**
     * @notice Generates QR code hash for batch verification
     */
    // @audit function can be vulnerable for hash collision
    function _generateQRCodeHash(
        uint256 _tokenId,
        string memory _batchNumber,
        address _manufacturer
    ) internal view returns (string memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                _tokenId,
                _batchNumber,
                _manufacturer,
                block.timestamp,
                block.chainid
            )
        );
        return _toHexString(hash);
    }

    /**
     * @notice Converts bytes32 to hex string
     */
    function _toHexString(bytes32 _hash) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = alphabet[uint8(_hash[i] >> 4)];
            str[1 + i * 2] = alphabet[uint8(_hash[i] & 0x0f)];
        }
        return string(str);
    }

    // VIEW FUNCTIONS

    /**
     * @notice Gets complete batch information
     */
    function getBatchInfo(uint256 _tokenId) external view tokenExists(_tokenId) returns (BatchInfo memory) {
        return s_batches[_tokenId];
    }

    /**
     * @notice Gets batch status for quick verification
     */
    function getBatchStatus(uint256 _tokenId) external view tokenExists(_tokenId) returns (BatchStatus) {
        return s_batches[_tokenId].status;
    }

    /**
     * @notice Gets QR code hash for scanning verification
     */
    function getQRCodeHash(uint256 _tokenId) external view tokenExists(_tokenId) returns (string memory) {
        return s_batches[_tokenId].qrCodeHash;
    }

    /**
     * @notice Verifies if a batch is authentic using QR code
     */
    function verifyBatchByQR(uint256 _tokenId, string memory _qrCodeHash) external view returns (bool) {
        if (_tokenId == 0 || _tokenId >= s_tokenCounter) return false;
        return keccak256(abi.encodePacked(s_batches[_tokenId].qrCodeHash)) == keccak256(abi.encodePacked(_qrCodeHash));
    }

    /**
     * @notice Gets complete supply chain history for a batch
     */
    function getSupplyChainHistory(uint256 _tokenId) external view tokenExists(_tokenId) returns (
        string memory medName,
        string memory batchNumber,
        uint256 quantity,
        uint256 expiryDate,
        address manufacturerAddress,
        address distributorAddress,
        address wholesalerAddress,
        address pharmacistAddress,
        BatchStatus status,
        uint256 createdAt,
        uint256 lastUpdated
    ) {
        BatchInfo memory batch = s_batches[_tokenId];
        return (
            batch.medName,
            batch.batchNumber,
            batch.quantity,
            batch.expiryDate,
            batch.manufacturerAddress,
            batch.distributorAddress,
            batch.wholesalerAddress,
            batch.pharmacistAddress,
            batch.status,
            batch.createdAt,
            batch.lastUpdated
        );
    }

    /**
     * @notice Gets basic medicine details
     */
    function getMedicineDetails(uint256 _tokenId) external view tokenExists(_tokenId) returns (
        string memory medName,
        string memory manufacturerName,
        string memory batchNumber,
        uint256 quantity,
        uint256 expiryDate
    ) {
        BatchInfo memory batch = s_batches[_tokenId];
        return (
            batch.medName,
            batch.manufacturerName,
            batch.batchNumber,
            batch.quantity,
            batch.expiryDate
        );
    }

    /**
     * @notice Checks if a batch has expired
     */
    function isBatchExpired(uint256 _tokenId) external view tokenExists(_tokenId) returns (bool) {
        return block.timestamp > s_batches[_tokenId].expiryDate;
    }

    /**
     * @notice Checks if a batch is locked
     */
    function isBatchLocked(uint256 _tokenId) external view tokenExists(_tokenId) returns (bool) {
        return s_batches[_tokenId].locked;
    }

    /**
     * @notice Gets current token counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return s_tokenCounter;
    }

    /**
     * @notice Gets merkle root for manufacturer verification
     */
    function getMerkleRoot() external view returns (bytes32) {
        return s_merkleRoot;
    }

    /**
     * @notice Checks if an address is an authorized manufacturer
     */
    function isAuthorizedManufacturer(address _manufacturer) external view returns (bool) {
        return s_authorizedManufacturers[_manufacturer];
    }
}