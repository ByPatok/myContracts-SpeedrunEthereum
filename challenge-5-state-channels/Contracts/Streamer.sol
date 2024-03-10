// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Streamer is Ownable {
  event Opened(address, uint256);
  event Challenged(address);
  event Withdrawn(address, uint256);
  event Closed(address);

  mapping(address => uint256) balances;
  mapping(address => uint256) canCloseAt;

  function fundChannel() public payable {
    /*
      Checkpoint 2: fund a channel

      Complete this function so that it:
      - reverts if msg.sender already has a running channel (ie, if balances[msg.sender] != 0)
      - updates the balances mapping with the eth received in the function call
      - emits an Opened event
    */
    if(balances[msg.sender] != 0) {
      revert("Channel already open");
    }
    balances[msg.sender] += msg.value;
    emit Opened(msg.sender, msg.value);
  }

  function timeLeft(address channel) public view returns (uint256) {
    if (canCloseAt[channel] == 0 || canCloseAt[channel] < block.timestamp) {
      return 0;
    }
    return canCloseAt[channel] - block.timestamp;
  }

  function withdrawEarnings(Voucher calldata voucher) public onlyOwner {
    // like the off-chain code, signatures are applied to the hash of the data
    // instead of the raw data itself
    bytes32 hashed = keccak256(abi.encode(voucher.updatedBalance));

    // The prefix string here is part of a convention used in ethereum for signing
    // and verification of off-chain messages. The trailing 32 refers to the 32 byte
    // length of the attached hash message.
    //
    // There are seemingly extra steps here compared to what was done in the off-chain
    // `reimburseService` and `processVoucher`. Note that those ethers signing and verification
    // functions do the same under the hood.
    //
    // see https://blog.ricmoo.com/verifying-messages-in-solidity-50a94f82b2ca
    bytes memory prefixed = abi.encodePacked("\x19Ethereum Signed Message:\n32", hashed);
    bytes32 prefixedHashed = keccak256(prefixed);

    address signer = ecrecover(prefixedHashed, voucher.sig.v, voucher.sig.r, voucher.sig.s);
    if (balances[signer] <= voucher.updatedBalance) {
      revert("Insufficient balance");
    }
    
    uint256 payment = balances[signer] - voucher.updatedBalance;
    balances[signer] -= payment;

    payable(owner()).transfer(payment);
    emit Withdrawn(signer, payment);
  
  }

    /*
      Checkpoint 4: Recover earnings

      The service provider would like to cash out their hard earned ether.
          - use ecrecover on prefixedHashed and the supplied signature
          - require that the recovered signer has a running channel with balances[signer] > v.updatedBalance
          - calculate the payment when reducing balances[signer] to v.updatedBalance
          - adjust the channel balance, and pay the Guru(Contract owner). Get the owner address with the `owner()` function.
          - emit the Withdrawn event
    */
  function challengeChannel() public {
    /*
      Checkpoint 5a: Challenge the channel

      Create a public challengeChannel() function that:
      - checks that msg.sender has an open channel
      - updates canCloseAt[msg.sender] to some future time
      - emits a Challenged event
    */
    if(balances[msg.sender] > 0) {
      canCloseAt[msg.sender] = block.timestamp + 30 seconds;
      emit Challenged(msg.sender);
    }
    else{
      revert("Channel not open");
    }
    
  }


  function defundChannel() public {
    /*
    Checkpoint 5b: Close the channel

    Create a public defundChannel() function that:
    - checks that msg.sender has a closing channel
    - checks that the current time is later than the closing time
        
    - sends the channel's remaining funds to msg.sender, and sets the balance to 0
    - emits the Closed event
  */
    require(canCloseAt[msg.sender] != 0, "No closing channel");
    require(block.timestamp > canCloseAt[msg.sender], "Channel not yet closed");

    uint256 payment = balances[msg.sender];
    balances[msg.sender] = 0;
    payable(msg.sender).transfer(payment);
    emit Closed(msg.sender);
    }
 

  struct Voucher {
    uint256 updatedBalance;
    Signature sig;
  }
  struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
  }


}
