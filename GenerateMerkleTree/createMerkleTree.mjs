import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";


const allowlist = [
    ["0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D"],
    ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
    ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8"],
    ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"],
    ["0x90F79bf6EB2c4f870365E785982E1f101E93b906"]
];


const tree = StandardMerkleTree.of(allowlist, ["address"]);

// returns the root of merkle tree
console.log('Merkle Root:', tree.root);


// write the complete merkle tree in tree.json
fs.writeFileSync("Target/tree.json", JSON.stringify(tree.dump()));


// merkle root : 0x44a82a0003fd32bbf9fa7417b707ebe79982b6eddd944227cf2d29de52c2b9f1
