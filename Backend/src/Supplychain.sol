// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SupplyChain contract
 * @author anurag shingare
 */

contract SupplyChain is ERC721, Ownable,AccessControl {
    // error
    error SupplyChain_ZeroAddressNotAllowed();
    error SupplyChain_AlreadyPresent_CheckForMaliciousActivity();
    error SupplyChain_DistributorAlreadyPresent_CheckForMaliciousActivity();
    error SupplyChain_WholeSalerAlreadyPresent_CheckForMaliciousActivity();
    error SupplyChain_PharmaAlreadyPresent_CheckForMaliciousActivity();
    error SupplyChain_NotOwnerOfTokenId();
    error SupplyChain_BatchIsLockedAndNowCannotTransferred();

    // type declaration
    enum batchStatus {
        Manufacturer,
        Distributor,
        WholeSaler,
        Pharma
    }
    struct Manufacturer {
        uint256 tokenId;
        bytes32 batchId;
        bytes32 temp;
        bytes32 manufacturingDate;
        bytes32 expiryDate;
        bytes32 medName;
        bytes32 manufacturerName;
        bytes32 distributorName;
        bytes32 wholeSalerName;
        bytes32 pharmaName;
        address currentOwner;
        batchStatus status;
        bool locked;
        // address[] owners;
        // bytes32[] batchImage
    }
    struct medicineInfo{
        uint256 tokenId;
        bytes32 batchId;
        bytes32 manufacturingDate;
        bytes32 expiryDate;
    }

    mapping (bytes32 batchId => Manufacturer batchInfo) private  s_createBatch;

    // state variables
    uint256 private tokenId;
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");

    // events
    event SupplyChain_BatchCreated(
        uint256 tokenId,
        bytes32 batchId,
        bytes32 temp,
        bytes32 manufacturingDate,
        bytes32 expiryDate,
        bytes32 medName,
        bytes32 manufacturerName,
        address currentOwner,
        batchStatus status
    );
    event SupplyChain_ManufacturerToDistributor(
        uint256 tokenId,
        bytes32 batchId,
        bytes32 medName,
        bytes32 manufacturerName,
        bytes32 distributorName,
        address currentOwner,
        batchStatus status
    );
    event SupplyChain_DistributorToWholeSaler(
        uint256 tokenId,
        bytes32 batchId,
        bytes32 medName,
        bytes32 distributorName,
        bytes32 wholeSalerName,
        address currentOwner,
        batchStatus status
    );
    event SupplyChain_WholeSalerToPharma(
        uint256 tokenId,
        bytes32 batchId,
        bytes32 medName,
        bytes32 wholeSalerName,
        bytes32 pharmaName,
        address currentOwner,
        batchStatus status
    );

    // modifiers
    modifier zeroAddressNotAllowed(address _to){
        if(_to == address(0)){
            revert SupplyChain_ZeroAddressNotAllowed();
        }
        _;
    }

    // functions
    constructor(
        address[] memory _allowlist
    )
        ERC721("MyToken", "MTK")
        Ownable(msg.sender)
    {
        tokenId = 0;
        for(uint256 i=0;i<_allowlist.length;i++){
            _grantRole(MANUFACTURER_ROLE, _allowlist[i]);
        }
    }

    /**
        @notice createMedicinebatch function
        @dev This function will create new batch of medicine and manufacturer will always create/mint the new NFT for each new batch
        @dev Manufacturer will fill all the info for each batch whenever new batch is created
    */
    function createMedicinebatch(
        bytes32 batchId,
        bytes32 temp,
        bytes32 manufacturingDate,
        bytes32 expiryDate,
        bytes32 medName,
        bytes32 manufacturerName
    ) public onlyRole(MANUFACTURER_ROLE){
        _safeMint(msg.sender, tokenId);

        if((s_createBatch[batchId].manufacturerName).length != 0){
            revert SupplyChain_AlreadyPresent_CheckForMaliciousActivity();
        }

        Manufacturer memory newManu = Manufacturer({
            tokenId:tokenId,
            batchId:batchId,
            temp:temp,
            manufacturingDate:manufacturingDate,
            expiryDate:expiryDate,
            medName:medName,
            manufacturerName:manufacturerName,
            currentOwner:msg.sender,
            status:batchStatus.Manufacturer,
            distributorName:"",
            wholeSalerName:"",
            pharmaName:"",
            locked:false
            // owners:[],
            // batchImage:""
        });

        s_createBatch[batchId] = newManu;

        emit SupplyChain_BatchCreated(
            tokenId,
            batchId,
            temp,
            manufacturingDate,
            expiryDate,
            medName,
            manufacturerName,
            msg.sender,
            batchStatus.Manufacturer
        );
        tokenId++;
    }


    /**
        @notice manufacturerToDistributor function
        @dev In this function manufacturer will transfer the ownership of NFT/batch to distributor
        @dev update the status of batch and also change the owner to distributor
        @dev update the distributor name and revert if the distributor name is already there!!!
    */
    function manufacturerToDistributor(
        bytes32 _batchId,
        address _distributor,
        bytes32 _distributorName
        ) public zeroAddressNotAllowed(_distributor) 
    {
        uint256 _tokenId = s_createBatch[_batchId].tokenId;
        // here the function will revert if manufacturer is not the owner of tokenID
        if(ownerOf(_tokenId) != msg.sender){
            revert SupplyChain_NotOwnerOfTokenId();
        }
        if((s_createBatch[_batchId].distributorName).length != 0){
            revert SupplyChain_DistributorAlreadyPresent_CheckForMaliciousActivity();
        }
        if(s_createBatch[_batchId].locked){
            revert SupplyChain_BatchIsLockedAndNowCannotTransferred();
        }

        safeTransferFrom(msg.sender, _distributor, _tokenId);
        s_createBatch[_batchId].distributorName = _distributorName;
        s_createBatch[_batchId].currentOwner = _distributor;
        s_createBatch[_batchId].status = batchStatus.Distributor;

        emit SupplyChain_ManufacturerToDistributor(
            _tokenId,
            _batchId,
            s_createBatch[_batchId].medName,
            s_createBatch[_batchId].manufacturerName,
            _distributorName,
            ownerOf(_tokenId),
            batchStatus.Distributor
        );
    }

    function distributorToWholeSaler(
        bytes32 _batchId,
        address _wholeSaler,
        bytes32 _wholeSalerName
    ) public {
        uint256 _tokenId = s_createBatch[_batchId].tokenId;
        // here the function will revert if manufacturer is not the owner of tokenID
        if(ownerOf(_tokenId) != msg.sender){
            revert SupplyChain_NotOwnerOfTokenId();
        }
        if((s_createBatch[_batchId].wholeSalerName).length != 0){
            revert SupplyChain_WholeSalerAlreadyPresent_CheckForMaliciousActivity();
        }
        if(s_createBatch[_batchId].locked){
            revert SupplyChain_BatchIsLockedAndNowCannotTransferred();
        }

        safeTransferFrom(msg.sender, _wholeSaler, _tokenId);
        s_createBatch[_batchId].wholeSalerName = _wholeSalerName;
        s_createBatch[_batchId].currentOwner = _wholeSaler;
        s_createBatch[_batchId].status = batchStatus.WholeSaler;

        emit SupplyChain_DistributorToWholeSaler(
            _tokenId,
            _batchId,
            s_createBatch[_batchId].medName,
            s_createBatch[_batchId].distributorName,
            _wholeSalerName,
            ownerOf(_tokenId),
            batchStatus.WholeSaler
        );
    }

    function wholeSalerToPharma(
        bytes32 _batchId,
        address _pharma,
        bytes32 _pharmaName
    ) public {
        uint256 _tokenId = s_createBatch[_batchId].tokenId;
        // here the function will revert if manufacturer is not the owner of tokenID
        if(ownerOf(_tokenId) != msg.sender){
            revert SupplyChain_NotOwnerOfTokenId();
        }
        if((s_createBatch[_batchId].pharmaName).length != 0){
            revert SupplyChain_PharmaAlreadyPresent_CheckForMaliciousActivity();
        }
        if(s_createBatch[_batchId].locked){
            revert SupplyChain_BatchIsLockedAndNowCannotTransferred();
        }

        safeTransferFrom(msg.sender, _pharma, _tokenId);
        s_createBatch[_batchId].locked = true;
        s_createBatch[_batchId].pharmaName = _pharmaName;
        s_createBatch[_batchId].currentOwner = _pharma;
        s_createBatch[_batchId].status = batchStatus.Pharma;

        emit SupplyChain_WholeSalerToPharma(
            _tokenId,
            _batchId,
            s_createBatch[_batchId].medName,
            s_createBatch[_batchId].wholeSalerName,
            _pharmaName,
            ownerOf(_tokenId),
            batchStatus.Pharma
        );
    }

    // GETTER FUNCTION
    function getBatchInfo(bytes32 _batchId) public view returns (Manufacturer memory){
        return s_createBatch[_batchId];
    }

    function getOwner(uint256 _tokenId) public view returns(address){
        return ownerOf(_tokenId);
    }
    function getManufacturerName(bytes32 _batchId) public view returns(bytes32){
        return s_createBatch[_batchId].manufacturerName;
    }
    function getDistributorName(bytes32 _batchId) public view returns(bytes32){
        return s_createBatch[_batchId].distributorName;
    }
    function getWholeSalerName(bytes32 _batchId) public view returns(bytes32){
        return s_createBatch[_batchId].wholeSalerName;
    }
    function getPharmaName(bytes32 _batchId) public view returns(bytes32){
        return s_createBatch[_batchId].pharmaName;
    }


    // INTERFACE FUNCTION
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}