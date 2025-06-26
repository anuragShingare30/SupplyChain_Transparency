import { ethers } from "ethers";

/**
 * Enhanced off-chain signature generation for supply chain transfers
 * Uses EIP-712 standard for structured data signing
 */

// Domain separator for EIP-712
const DOMAIN = {
    name: "MedicineSupplyChain",
    version: "1.0",
    chainId: 1, // Change this to your network's chain ID
    verifyingContract: "0x0000000000000000000000000000000000000000" // Replace with actual contract address
};

// Type definition for transfer signatures
const TRANSFER_TYPES = {
    Transfer: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "tokenId", type: "uint256" },
        { name: "timestamp", type: "uint256" }
    ]
};

/**
 * Generate signature for batch transfer
 * @param {Object} signer - Ethers signer object
 * @param {string} fromAddress - Current owner address
 * @param {string} toAddress - Recipient address
 * @param {number} tokenId - Token ID being transferred
 * @param {number} timestamp - Current timestamp
 * @returns {Object} Signature components {v, r, s}
 */
export async function generateTransferSignature(signer, fromAddress, toAddress, tokenId, timestamp) {
    const transferData = {
        from: fromAddress,
        to: toAddress,
        tokenId: tokenId,
        timestamp: timestamp
    };

    try {
        const signature = await signer._signTypedData(DOMAIN, TRANSFER_TYPES, transferData);
        
        // Split signature into v, r, s components
        const { v, r, s } = ethers.utils.splitSignature(signature);
        
        return {
            v: v,
            r: r,
            s: s,
            signature: signature
        };
    } catch (error) {
        console.error("Error generating signature:", error);
        throw error;
    }
}

/**
 * Verify signature off-chain (for testing purposes)
 * @param {string} fromAddress - Signer address
 * @param {string} toAddress - Recipient address
 * @param {number} tokenId - Token ID
 * @param {number} timestamp - Timestamp
 * @param {string} signature - Full signature string
 * @returns {string} Recovered address
 */
export function verifyTransferSignature(fromAddress, toAddress, tokenId, timestamp, signature) {
    const transferData = {
        from: fromAddress,
        to: toAddress,
        tokenId: tokenId,
        timestamp: timestamp
    };

    try {
        const recoveredAddress = ethers.utils.verifyTypedData(
            DOMAIN,
            TRANSFER_TYPES,
            transferData,
            signature
        );
        
        return recoveredAddress;
    } catch (error) {
        console.error("Error verifying signature:", error);
        throw error;
    }
}

/**
 * Example usage for manufacturer to distributor transfer
 */
export async function manufacturerToDistributor(manufacturerSigner, distributorAddress, tokenId) {
    const timestamp = Math.floor(Date.now() / 1000);
    const manufacturerAddress = await manufacturerSigner.getAddress();
    
    const signature = await generateTransferSignature(
        manufacturerSigner,
        manufacturerAddress,
        distributorAddress,
        tokenId,
        timestamp
    );
    
    console.log("Transfer Signature Generated:");
    console.log("From:", manufacturerAddress);
    console.log("To:", distributorAddress);
    console.log("Token ID:", tokenId);
    console.log("Timestamp:", timestamp);
    console.log("Signature components:", signature);
    
    return {
        ...signature,
        timestamp,
        fromAddress: manufacturerAddress,
        toAddress: distributorAddress,
        tokenId
    };
}

/**
 * Update domain with actual contract address
 * @param {string} contractAddress - Deployed contract address
 * @param {number} chainId - Network chain ID
 */
export function updateDomain(contractAddress, chainId) {
    DOMAIN.verifyingContract = contractAddress;
    DOMAIN.chainId = chainId;
}

// Example usage (commented out)
/*
async function exampleUsage() {
    // Create a wallet (in real app, this would be connected wallet)
    const wallet = new ethers.Wallet("0x" + "your_private_key_here");
    
    // Update contract address
    updateDomain("0xYourContractAddress", 1);
    
    // Generate signature for transfer
    const result = await manufacturerToDistributor(
        wallet,
        "0xDistributorAddress",
        1
    );
    
    console.log("Result:", result);
}
*/
