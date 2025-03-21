// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
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
    error NewSupplyChain_InvalidSIgnature_ByDistributor();
    error NewSupplyChain_InvalidSIgnature_ByRetailer();
    error NewSupplyChain_InvalidSIgnature_ByPharmacists();
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
    // bytes32[] private _merkleProof = [
    //     bytes32(0x59856afbe8900ffcd32b8de545b9b5c0128ecda7289ff898b2ea8dc62b3f9a07),
    //     bytes32(0xf6949786c44ce4b9916e434fcdb9ff65f5c1c50d4fd00c0c34ce124acb64a922),
    //     bytes32(0x079d80974de7a6a2b5658681d9914e122e80917d90056c1f9d6b3ad021733efc)
    // ];


    // events
    event NewSupplyChain__ValidProof(address _user);
    event NewSupplyChain__ValidSignature__ManufacturerToDistributor(address _manufacturer,address _distributor);
    event NewSupplyChain__ValidSignature__DistributorToWholeSaler(address _distributor,address _wholeSaler);
    event NewSupplyChain__ValidSignature__WholeSalerToPharmacists(address _wholeSaler, address _pharmacists);

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

    /**
        @notice createBatch function
        @notice This function will be called by manufacturer only!!!
        @notice Function checks for valid address present in our tree
        @dev The addresses present in merkle tree are eligible to create medicine batch
        @dev If calling address is eligible -> mints new medicine batch -> Updates the batch struct
     */
    function createBatch(
        bytes32 _merkleRoot,
        bytes32[] memory _merkleProof,
        string memory _expiryDate,
        string memory _medName,
        string memory _manufacturerName
    ) public zeroAddressNotAllowed(msg.sender){

        // if((s_createBatch[tokenId].manufacturerName).length != 0){
        //     revert NewSupplyChain_AlreadyPresent_CheckForMaliciousActivity();
        // }
        
        // validated the user using merkle root
        // Here, for frontend we will hardcode the merkle proofs for specific address 
        // Here, caller will not provide the proof
        // Protocol will fetch the proof for caller off-chain -> If no proof exist zero address will be returned
        bytes32 leaf = keccak256(bytes.concat(keccak256((abi.encode(msg.sender)))));
        if(!MerkleProof.verify(_merkleProof, _merkleRoot, leaf)){
            revert NewSupplyChain_InvalidProof();
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

        // approve the contract
        setApprovalForAll(address(this), true);

        tokenId++;
    }


    /**
        @notice toDistributor function
        @notice Function performs an pre-authorization to verify the transfership to trusted and valid distributor!!!
        @notice This function will be called by distributor and need to provide the signature for verification
        @notice The valid manufacturer will generate the signature off-chain
        @notice Protocol will verify the signature on-chain provided by the distributor. If elgible the ownership will be transfered to distributor

        @dev Gas-less transaction -> Pre-authorization
        @dev Message can contains either the signer address or the struct of batch info!!!!
        @dev We can use Ether.js or Web3.js to generate the signature
        @dev We can use lower-level calls and functions to split the signature in v,r,s
     */
    function toDistributor(
        address _signer, // manufacturer address
        // bytes memory _signature,
        uint8 _v,
	    bytes32 _r,
	    bytes32 _s,
        uint256 _tokenId,
        string memory _distributorName
    ) public {

        // verify the signature
        bytes32 digest = _getMessageHash(_signer);
        if(!_isVaildSignature(_signer, digest, _v,_r,_s)){
            revert NewSupplyChain_InvalidSIgnature_ByDistributor();
        }

        // update the batch info
        s_createBatch[_tokenId].distributorName = bytes32(abi.encodePacked(_distributorName));
        s_createBatch[_tokenId].status = batchStatus.Distributor;

        emit NewSupplyChain__ValidSignature__ManufacturerToDistributor(_signer,msg.sender); 

        // transfer ownership
        // safeTransferFrom(address(this), msg.sender, _tokenId);
    }


    function toWholesaler(
        address _signer, // distributor address
        // bytes memory _signature,
        uint8 _v,
	    bytes32 _r,
	    bytes32 _s,
        uint256 _tokenId,
        string memory _wholeSalerName
    ) public {
                // verify the signature
        bytes32 digest = _getMessageHash(_signer);
        if(!_isVaildSignature(_signer, digest, _v,_r,_s)){
            revert NewSupplyChain_InvalidSIgnature_ByWholesaler();
        }

        // update the batch info
        s_createBatch[_tokenId].wholeSalerName = bytes32(abi.encodePacked(_wholeSalerName));
        s_createBatch[_tokenId].status = batchStatus.WholeSaler;

        emit NewSupplyChain__ValidSignature__DistributorToWholeSaler(_signer,msg.sender); 
    }


    function toPharmacists(
        address _signer, // distributor address
        // bytes memory _signature,
        uint8 _v,
	    bytes32 _r,
	    bytes32 _s,
        uint256 _tokenId,
        string memory _pharmacistsName
    ) public {
                // verify the signature
        bytes32 digest = _getMessageHash(_signer);
        if(!_isVaildSignature(_signer, digest, _v,_r,_s)){
            revert NewSupplyChain_InvalidSIgnature_ByPharmacists();
        }

        // update the batch info
        s_createBatch[_tokenId].wholeSalerName = bytes32(abi.encodePacked(_wholeSalerName));
        s_createBatch[_tokenId].status = batchStatus.WholeSaler;

        emit NewSupplyChain__ValidSignature__WholeSalerToPharmacists(_signer,msg.sender); 
    }


    // INTERNAL FUNCTIONS
    function _isVaildSignature(
        address _signer,
        bytes32 _digest,
        // bytes memory _signature
        uint8 _v,
	    bytes32 _r,
	    bytes32 _s
    ) internal returns(bool){
        (address actualSigner,,) = ECDSA.tryRecover(_digest, _v,_r,_s); 
        return (actualSigner == _signer);
    }

    
    // GETTER FUNCTION
    function _getMessageHash(address _signer) public pure returns(bytes32){
        return (
            keccak256(
                abi.encode(
                    _signer
                )
            )
        );
    } 

    function getBatchInfo(uint256 _tokenId) public view returns(batchInfo memory){
        return s_createBatch[_tokenId];
    }

    function getSomeDetails(uint256 _tokenId) public view returns(bytes32,bytes32){
        return (s_createBatch[_tokenId].medName,s_createBatch[_tokenId].manufacturerName);
    }
    function getDistName(uint256 _tokenId) public view returns(string memory){
        bytes32 _distName = s_createBatch[_tokenId].distributorName;
        return string(abi.encodePacked(_distName));
    }
}