import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("Target/tree.json", "utf8")));

// (2) on frontend we can enable the gas payer to access the proofs by passing the address details
for (const [i, v] of tree.entries()) {
  if (v[0] === '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4') {
    // (3)
    const proof = tree.getProof(i);
    console.log('Value:', v);
    console.log('Proof:', proof);
    // writing proof for address(account) in proof.json
    fs.writeFileSync("Target/proof.json", JSON.stringify(proof));
  }
}



// On frontend we can use this function to get the proofs for specific user
// Function to get proof dynamically
function getProofForUser(address) {
    for (const [i, v] of tree.entries()) {
        if (v[0] === address) {
            return tree.getProof(i); // Return proof directly
        }
    }
    return []; // Return empty proof if user not found
}

// Example Usage
const userAddress = '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4';
const proof = getProofForUser(userAddress);

console.log(`Proof for ${userAddress}:`, proof);
