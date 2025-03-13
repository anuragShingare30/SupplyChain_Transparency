// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test,Vm} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {NewSupplyChain} from "src/NewSupplychain.sol";

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
    bytes32[] public merkleProof;

    function setUp() public {
        newSupplychain = new NewSupplyChain();

        (user,userPK) = makeAddrAndKey("user");
    }

    
}