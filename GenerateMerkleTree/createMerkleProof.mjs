import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("Target/tree.json", "utf8")));

// (2) on frontend we can enable the gas payer to access the proofs by passing the address details
for (const [i, v] of tree.entries()) {
  if (v[0] === '0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D') {
    // (3)
    const proof = tree.getProof(i);
    console.log('Value:', v);
    console.log('Proof:', proof);
    // writing proof for address(account) in proof.json
    fs.writeFileSync("Target/proof.json", JSON.stringify(proof));
  }
}