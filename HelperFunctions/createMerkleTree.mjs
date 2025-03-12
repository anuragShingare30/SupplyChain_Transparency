import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";


const allowlist = [
    ["0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D"],
    ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
    ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"],
    ["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2"],
    ["0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db"]
];


const tree = StandardMerkleTree.of(allowlist, ["address"]);

// returns the root of merkle tree
// on frontend -> instead of fetching root from json we can create a function which will dynamically return the merkle root
function getMerkleRoot(){
    return tree.root;
}

console.log("Merkle Root :",getMerkleRoot());


// write the complete merkle tree in tree.json
fs.writeFileSync("Target/tree.json", JSON.stringify(tree.dump()));