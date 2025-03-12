// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title NewSupplyChain contract
 * @author anurag shingare

 * @dev The task and flow of application to follow:
    1. createMedicineBatch -> check for validate user stored in tree -> only eligible user will able to createBatch.
 */

contract NewSupplyChain is ERC721,Ownable {
    // error
    error NewSupplyChain__InvalidProof();

    // enum
    enum batchStatus { 
        Manufacturer,
        Distributor,
        WholeSaler,
        Pharma
    }

    // type declaration
    struct batchInfo {
        uint256 tokenId;
        bytes32 expiryDate;
        bytes32 medName;
        bytes32 manufacturerName;
        bytes32 distributorName;
        bytes32 wholeSalerName;
        bytes32 pharmaName;
        batchStatus status;
        bool locked;
    }

    mapping(uint256 _tokenId => batchInfo _batchInfo) public s_createBatch;

    // state variables
    uint256 tokenId;


    // events
    event NewSupplyChain__ValidProof(address _user);


    constructor()
        ERC721("MyToken", "MTK")
        Ownable(msg.sender)
    {
        tokenId = 0;
    }

    function createBatch(
        address user,
        bytes32 _merkleRoot,
        bytes32[] memory _merkleProof,
        bytes32 _expiryDate,
        bytes32 _medName,
        bytes32 _manufacturerName
    ) public {
        
        // validate user
        bytes32 leafNode = keccak256(bytes.concat(keccak256(abi.encode(user))));
        if(!MerkleProof.verify(_merkleProof, _merkleRoot, leafNode)){
            revert NewSupplyChain__InvalidProof();
        }

        _safeMint(user, tokenId);

        batchInfo memory tempManufacturer = batchInfo({
             tokenId:tokenId,
             expiryDate:_expiryDate,
             medName:_medName,
             manufacturerName:_manufacturerName,
             distributorName:"",
             wholeSalerName:"",
             pharmaName:"",
             status:batchStatus.Manufacturer,
             locked:false
        });

        s_createBatch[tokenId] = tempManufacturer;

        emit NewSupplyChain__ValidProof(user);

        tokenId++;
    }
}