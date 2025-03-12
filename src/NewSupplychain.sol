// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NewSupplyChain contract
 * @author anurag shingare

 * @dev The task and flow of application to follow:
    1. createMedicineBatch -> check for validate user stored in tree -> only eligible user will able to createBatch.
    2. transfer ownership to distributor -> verify the signature -> generate sig. off-chain -> verify it on-chain
 */

contract NewSupplyChain is ERC721,Ownable,EIP712 {
    using ECDSA for bytes32;


    // error
    error NewSupplyChain_InvalidProof();
    error NewSupplyChain_ZeroAddressNotAllowed();
    error NewSupplyChain_AlreadyPresent_CheckForMaliciousActivity();

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
        uint256 timeStamp;
    }

    mapping(uint256 _tokenId => batchInfo _batchInfo) public s_createBatch;

    // state variables
    uint256 tokenId;
    bytes32[] private _merkleProof = [
        bytes32(0x59856afbe8900ffcd32b8de545b9b5c0128ecda7289ff898b2ea8dc62b3f9a07),
        bytes32(0xf6949786c44ce4b9916e434fcdb9ff65f5c1c50d4fd00c0c34ce124acb64a922),
        bytes32(0x079d80974de7a6a2b5658681d9914e122e80917d90056c1f9d6b3ad021733efc)
    ];


    // events
    event NewSupplyChain__ValidProof(address _user);
    event NewSupplyChain__ValidSignature__ManufacturerToDistributor(address _signer,address _distributor);

    // modifiers
    modifier zeroAddressNotAllowed(address _to){
        if(_to == address(0)){
            revert NewSupplyChain_ZeroAddressNotAllowed();
        }
        _;
    }


    constructor()
        ERC721("MyToken", "MTK")
        Ownable(msg.sender)
        EIP712("SupplyChain","1.0")
    {
        tokenId = 0;
    }

    function createBatch(
        bytes32 _merkleRoot,
        string memory _expiryDate,
        string memory _medName,
        string memory _manufacturerName
    ) public zeroAddressNotAllowed(msg.sender){

        if((s_createBatch[tokenId].manufacturerName).length != 0){
            revert NewSupplyChain_AlreadyPresent_CheckForMaliciousActivity();
        }
        
        // validated the user using merkle root
        // Here, for frontend we will hardcode the merkle proofs for specific address 
        bytes32 leaf = keccak256(bytes.concat(keccak256((abi.encode(msg.sender)))));
        if(!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)){
            revert NewSupplyChain__InvalidProof();
        }

        _safeMint(msg.sender, tokenId);

        batchInfo memory tempManufacturer = batchInfo({
             tokenId:tokenId,
             expiryDate:bytes32(abi.encodePacked(_expiryDate)),
             medName:bytes32(abi.encodePacked(_medName)),
             manufacturerName:bytes32(abi.encodePacked(_manufacturerName)),
             distributorName:"",
             wholeSalerName:"",
             pharmaName:"",
             status:batchStatus.Manufacturer,
             locked:false,
             timeStamp:block.timestamp
        });

        s_createBatch[tokenId] = tempManufacturer;

        emit NewSupplyChain__ValidProof(msg.sender);

        tokenId++;
    }


    // We can use Ether.js or Web3.js to generate the signature
    // We can use lower-level calls and functions to split the signature in v,r,s
    // Here, we will implement the pre-authorization for transfer
    // Manufacturer will sign the message off-chain and verified distributor will verify the signature
    // Protocol will check for verification -> If correct ownership will be transfered to the distributor
    // Gas-less transaction -> Pre-authorization
    // Message can contains either the signer address or the struct of batch info!!!!
    function toDistributor(
        address _signer, // manufacturer address
        bytes memory _signature,
        uint256 _tokenId,
        string memory _distributorName
    ) public {

        // verify the signature
        bytes32 digest = _getMessageHash(_signer);
        if(!_isVaildSignature(_signer, digest, _signature)){
            revert NewSupplyChain_InvalidProof();
        }

        // update the batch info
        s_createBatch[_tokenId].distributorName = keccak256(abi.encodePacked(_distributorName));
        s_createBatch[_tokenId].status = batchStatus.Distributor;

        emit NewSupplyChain__ValidSignature__ManufacturerToDistributor(_signer,msg.sender); 

        // transfer ownership
        safeTransferFrom(_signer, msg.sender, _tokenId);
    }


    // INTERNAL FUNCTIONS
    function _isVaildSignature(
        address _signer,
        bytes32 _digest,
        bytes memory _signature
    ) internal returns(bool){
        (address actualSigner,,) = ECDSA.tryRecover(_digest, _signature);
        return (actualSigner == _signer);
    }

    
    // GETTER FUNCTION
    function _getMessageHash(address _signer) internal pure returns(bytes32){
        return (
            keccak256(
                abi.encode(
                    _signer
                )
            )
        );
    } 
}