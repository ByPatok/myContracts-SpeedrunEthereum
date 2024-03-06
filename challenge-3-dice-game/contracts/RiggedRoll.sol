pragma solidity >=0.8.0 <0.9.0;  //Do not change the solidity version as it negativly impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {

    DiceGame public diceGame;
    uint public nonce = 0;

    uint256 diceGameBalance = address(diceGame).balance;

    error NotEnoughEtherRigged();

    constructor(address payable diceGameAddress) {
        diceGame = DiceGame(diceGameAddress);
    }

    // Implement the `withdraw` function to transfer Ether from the rigged contract to a specified address.
    function withdraw(address payable _to, uint256 _amount) public onlyOwner {
        _to.transfer(_amount);
    }

    // Predict the randomness in the DiceGame contract and only initiate a roll when it guarantees a win.


    // Create the `riggedRoll()` function to predict the randomness in the DiceGame contract and only initiate a roll when it guarantees a win.
    function riggedRoll() public payable {
        if (address(this).balance < 0.002 ether) {
            revert NotEnoughEtherRigged();
        }
        bytes32 prevHash = blockhash(block.number - 1);
        bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), diceGame.nonce()));
        uint256 roll = uint256(hash) % 16;
        nonce++;
        
        uint value = 0.002 ether;
        require(roll <= 5, "roll was greater than 5");
        diceGame.rollTheDice{value: value}();
    }

    // Include the `receive()` function to enable the contract to receive incoming Ether.
    receive() external payable {}

}
