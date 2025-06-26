// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.22;

// import {Test,Vm} from "lib/forge-std/src/Test.sol";
// import "lib/forge-std/src/console.sol";
// import {NewSupplyChain} from "src/NewSupplychain.sol";
// import "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

// contract NewSupplyChainTest is Test {
//     NewSupplyChain public supplyChain;
    
//     // Test addresses
//     address public manufacturer = address(0x1234);
//     address public distributor = address(0x5678);
//     address public wholesaler = address(0x9ABC);
//     address public pharmacy = address(0xDEF0);
    
//     // Test data
//     bytes32 public merkleRoot;
//     bytes32[] public merkleProof;
    
//     // Test batch data
//     string constant MEDICINE_NAME = "Aspirin 100mg";
//     string constant MANUFACTURER_NAME = "PharmaCorp Inc";
//     string constant BATCH_NUMBER = "BATCH001";
//     uint256 constant QUANTITY = 1000;
//     uint256 constant EXPIRY_DATE = 1735689600; // Jan 1, 2025
    
//     function setUp() public {
//         // Create a simple merkle tree for testing
//         // In practice, this would be generated off-chain
//         merkleRoot = keccak256(abi.encodePacked("test_merkle_root"));
//         merkleProof.push(keccak256(abi.encodePacked("proof1")));
//         merkleProof.push(keccak256(abi.encodePacked("proof2")));
        
//         // Deploy contract
//         supplyChain = new NewSupplyChain(merkleRoot);
        
//         // Setup test accounts
//         vm.deal(manufacturer, 1 ether);
//         vm.deal(distributor, 1 ether);
//         vm.deal(wholesaler, 1 ether);
//         vm.deal(pharmacy, 1 ether);
//     }
    
//     function testDeployment() public {
//         assertEq(supplyChain.getMerkleRoot(), merkleRoot);
//         assertEq(supplyChain.getCurrentTokenId(), 1);
//         assertEq(supplyChain.name(), "MedicineSupplyChain");
//         assertEq(supplyChain.symbol(), "MSC");
//     }
    
//     function testCreateBatch() public {
//         // Mock the merkle proof verification
//         vm.mockCall(
//             address(supplyChain),
//             abi.encodeWithSelector(MerkleProof.verify.selector),
//             abi.encode(true)
//         );
        
//         vm.prank(manufacturer);
//         supplyChain.createBatch(
//             merkleProof,
//             MEDICINE_NAME,
//             MANUFACTURER_NAME,
//             BATCH_NUMBER,
//             QUANTITY,
//             EXPIRY_DATE
//         );
        
//         // Verify batch was created
//         assertEq(supplyChain.ownerOf(1), manufacturer);
//         assertEq(supplyChain.getCurrentTokenId(), 2);
        
//         // Check batch info
//         NewSupplyChain.BatchInfo memory batchInfo = supplyChain.getBatchInfo(1);
//         assertEq(batchInfo.tokenId, 1);
//         assertEq(batchInfo.medName, MEDICINE_NAME);
//         assertEq(batchInfo.manufacturerName, MANUFACTURER_NAME);
//         assertEq(batchInfo.batchNumber, BATCH_NUMBER);
//         assertEq(batchInfo.quantity, QUANTITY);
//         assertEq(batchInfo.expiryDate, EXPIRY_DATE);
//         assertTrue(batchInfo.status == NewSupplyChain.BatchStatus.Manufactured);
//     }
    
//     function testBatchStatusUpdates() public {
//         // First create a batch
//         testCreateBatch();
        
//         // Test status retrieval
//         NewSupplyChain.BatchStatus status = supplyChain.getBatchStatus(1);
//         assertTrue(status == NewSupplyChain.BatchStatus.Manufactured);
        
//         // Test other view functions
//         assertFalse(supplyChain.isBatchExpired(1));
//         assertFalse(supplyChain.isBatchLocked(1));
//         assertTrue(supplyChain.isAuthorizedManufacturer(manufacturer));
//     }
    
//     function testQRCodeGeneration() public {
//         testCreateBatch();
        
//         string memory qrHash = supplyChain.getQRCodeHash(1);
//         assertTrue(bytes(qrHash).length > 0);
        
//         // Test QR verification
//         assertTrue(supplyChain.verifyBatchByQR(1, qrHash));
//         assertFalse(supplyChain.verifyBatchByQR(1, "invalid_hash"));
//     }
    
//     function testMedicineDetails() public {
//         testCreateBatch();
        
//         (
//             string memory medName,
//             string memory manufacturerName,
//             string memory batchNumber,
//             uint256 quantity,
//             uint256 expiryDate
//         ) = supplyChain.getMedicineDetails(1);
        
//         assertEq(medName, MEDICINE_NAME);
//         assertEq(manufacturerName, MANUFACTURER_NAME);
//         assertEq(batchNumber, BATCH_NUMBER);
//         assertEq(quantity, QUANTITY);
//         assertEq(expiryDate, EXPIRY_DATE);
//     }
    
//     function testSupplyChainHistory() public {
//         testCreateBatch();
        
//         (
//             string memory medName,
//             string memory batchNumber,
//             uint256 quantity,
//             uint256 expiryDate,
//             address manufacturerAddress,
//             address distributorAddress,
//             address wholesalerAddress,
//             address pharmacistAddress,
//             NewSupplyChain.BatchStatus status,
//             uint256 createdAt,
//             uint256 lastUpdated
//         ) = supplyChain.getSupplyChainHistory(1);
        
//         assertEq(medName, MEDICINE_NAME);
//         assertEq(batchNumber, BATCH_NUMBER);
//         assertEq(quantity, QUANTITY);
//         assertEq(expiryDate, EXPIRY_DATE);
//         assertEq(manufacturerAddress, manufacturer);
//         assertEq(distributorAddress, address(0));
//         assertEq(wholesalerAddress, address(0));
//         assertEq(pharmacistAddress, address(0));
//         assertTrue(status == NewSupplyChain.BatchStatus.Manufactured);
//         assertTrue(createdAt > 0);
//         assertTrue(lastUpdated > 0);
//     }
    
//     function testEmergencyFunctions() public {
//         testCreateBatch();
        
//         // Test batch locking (owner only)
//         supplyChain.lockBatch(1);
//         assertTrue(supplyChain.isBatchLocked(1));
        
//         // Test batch unlocking
//         supplyChain.unlockBatch(1);
//         assertFalse(supplyChain.isBatchLocked(1));
        
//         // Test merkle root update
//         bytes32 newMerkleRoot = keccak256(abi.encodePacked("new_merkle_root"));
//         supplyChain.updateMerkleRoot(newMerkleRoot);
//         assertEq(supplyChain.getMerkleRoot(), newMerkleRoot);
//     }
    
//     function testFailCreateBatchWithInvalidInputs() public {
//         vm.prank(manufacturer);
        
//         // Test with empty medicine name
//         vm.expectRevert("Medicine name cannot be empty");
//         supplyChain.createBatch(
//             merkleProof,
//             "",
//             MANUFACTURER_NAME,
//             BATCH_NUMBER,
//             QUANTITY,
//             EXPIRY_DATE
//         );
        
//         // Test with zero quantity
//         vm.expectRevert("Quantity must be greater than 0");
//         supplyChain.createBatch(
//             merkleProof,
//             MEDICINE_NAME,
//             MANUFACTURER_NAME,
//             BATCH_NUMBER,
//             0,
//             EXPIRY_DATE
//         );
        
//         // Test with past expiry date
//         vm.expectRevert("Expiry date must be in the future");
//         supplyChain.createBatch(
//             merkleProof,
//             MEDICINE_NAME,
//             MANUFACTURER_NAME,
//             BATCH_NUMBER,
//             QUANTITY,
//             block.timestamp - 1
//         );
//     }
    
//     function testFailNonExistentToken() public {
//         vm.expectRevert(NewSupplyChain.NewSupplyChain_TokenDoesNotExist.selector);
//         supplyChain.getBatchInfo(999);
//     }
    
//     function testFailZeroAddress() public {
//         vm.expectRevert(NewSupplyChain.NewSupplyChain_ZeroAddressNotAllowed.selector);
//         supplyChain.transferToDistributor(
//             manufacturer,
//             address(0),
//             1,
//             "Test Distributor",
//             27,
//             bytes32(0),
//             bytes32(0)
//         );
//     }
// }
