// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test,Vm} from "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import {NewSupplyChain} from "src/NewSupplychain.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

/**
    @notice SupplychainTest test contract
    @notice We will implement a function which contains the complete flow of the application that will follow below flow:
        1. Manufacturer will create new batch of medicines. Protocol will verify manufacturer eligibility in merkle tree.
        2. Manufacturer will generate the signature off-chain (pre-authorization)
        3. Distributor will provide signature -> protocol will verify the signature -> If verified ownership will be transfered to distributor
        4. Distributor will update a single data for medicines batch!!!
 */

contract SupplychainTest is Test {
    NewSupplyChain public newSupplychain;

    address user;
    address DIST;
    uint256 userPK;

    bytes32 public merkleRoot = 0xd236e5c3bffa45c2373ae9ad1c5e66728a24f0eac87aa457f08153425ad2ac01;
    bytes32[] public merkleProof = [
        bytes32(0x85c99f9ed408529a8e32d19f1606c0783273722f7a42ae71ef5f7345b0e62870),
        bytes32(0x079d80974de7a6a2b5658681d9914e122e80917d90056c1f9d6b3ad021733efc)
    ];

    function setUp() public {
        newSupplychain = new NewSupplyChain();

        (user,userPK) = makeAddrAndKey("user");
        DIST = makeAddr("DIST");
    }

    // CREATING BATCH AND VERIFYING VALID USER/MANUFACTURER CREATED BATCH
    function test_createBatchByValidUser() public {
        vm.startPrank(user);
        string memory _expiryDate = "12/12/12";
        string memory _medName = "Para123";
        string memory _manfName = "Rohit";
        newSupplychain.createBatch(merkleRoot,merkleProof,_expiryDate,_medName,_manfName);

        (bytes32 medName, bytes32 manuName) = newSupplychain.getSomeDetails(0);
        vm.stopPrank();

        console.log(string(abi.encodePacked(medName)));
        console.log(string(abi.encodePacked(manuName)));
    }

    // VERIFYING THE SIGNATURE AND TRANSFERRING OWNERSHIP
    function test_verifySigNTransferOwnerShip() public {
        // create batch
        vm.startPrank(user);
        string memory _expiryDate = "12/12/12";
        string memory _medName = "Para123";
        string memory _manfName = "Rohit";
        newSupplychain.createBatch(merkleRoot,merkleProof,_expiryDate,_medName,_manfName);
        vm.stopPrank();

        // pre-authentication to generate signature
        // bytes memory sig = abi.encodePacked(r, s, v);
        // console.logBytes(sig);
        bytes32 digest = newSupplychain._getMessageHash(user);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);

        // VERIFY THE SIGNATURE
        string memory _distName = "Anurag";
        vm.startPrank(DIST);
        newSupplychain.toDistributor(user,v,r,s,0,_distName);
        vm.stopPrank();

        // TRANSFER THE OWNERSHIP -> AS CONTRACT AS APPROVAL TO TRANSFER OWNERSHIP
        vm.startPrank(user);
        IERC721(newSupplychain).safeTransferFrom(user, DIST, 0);
        vm.stopPrank();

        assert(newSupplychain.ownerOf(0) == DIST);
        console.log(string(abi.encodePacked(newSupplychain.getDistName(0))));
    }


}