pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
  event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
  event TokenBuyBack(address buyer, uint amountOfTokens, uint amountOfETH);
  event whithdrawn(address taker, uint amountTaken);

  mapping (address => uint) buyers;

  YourToken public yourToken;
  uint public constant tokensPerEth = 100;

  constructor(address tokenAddress) {
    yourToken = YourToken(tokenAddress);
  }

  // ToDo: create a payable buyTokens() function:
  function buyTokens () public payable {
    require(msg.value > 0);
    uint tokenAmount = msg.value * tokensPerEth;
    buyers[msg.sender] = msg.value;
    yourToken.transfer(msg.sender, tokenAmount);
    emit BuyTokens(msg.sender , msg.value, tokenAmount);
  }

  // ToDo: create a withdraw() function that lets the owner withdraw ETH
  function withdraw() onlyOwner public payable {
    uint amount = address(this).balance;
    require(amount > 0, "No ether in balance");
    address _owner = owner();
    (bool sent, ) = _owner.call{value: amount}("");
    require(sent, "Failed to withdraw");
    
    emit whithdrawn(_owner, amount);
  }

  // ToDo: create a sellTokens(uint256 _amount) function:
  function sellTokens(uint _amount) public payable {
    address sendTo = address(this);
    uint tokenAmount = _amount / tokensPerEth; // Quantidade de ETH pra pagar
    require(yourToken.balanceOf(msg.sender) >= _amount, "token insuficiente" );
    require(yourToken.transferFrom(msg.sender, sendTo, _amount));
    (bool success, ) = payable(msg.sender).call{value: tokenAmount}("");
    require(success, "failed lol");
    
    

    emit TokenBuyBack(msg.sender, _amount, msg.value);
  }

}
