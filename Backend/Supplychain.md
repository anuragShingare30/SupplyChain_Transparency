# About Application

**Supplychain transparency and tokenization of medicines and fraud-detection protocol**

1. Application aims to solve the fraud supply of medicines throughout the supplychain of medicines
2. Manufacturer will create the batch of medicines by minting an ERC-721(unique tokenId) NFT.
3. Protocol will verify the Manufacturer addresses in `merkle trees` using `merkle proofs`
4. After verification -> Manufacturer will update the batch data and perform an `pre-authentication by signing a msg`
5. Distributor will provide signature to protocol -> protocol will verify signature`signature standards(EIP-712 and EIP-191)`
6. After verification -> protocol will `transfer ownership` to Distributor -> Distributor will update data
7. Process continues for -> `Wholesaler` -> `Pharmacists`
8. End user will `scans QR code` to check the complete supplychain on-chain!!!! 