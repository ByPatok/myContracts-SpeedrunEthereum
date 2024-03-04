// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; // Only change if u know tf u r doing (i don't)


import "./ExampleExternalContract.sol";

contract Staker {

    event NewStake(address _stakeSender, uint _stakeAmount); 

    mapping (address => uint256) public balances; 

    uint256 public constant threshold = 1 ether; 

    enum State { StakingPeriod, Success, Withdraw } 

    State public currentState = State.StakingPeriod; 


    uint256 deploymentTime = block.timestamp;
    uint256 deadline = deploymentTime + 72 hours;
    bool public openForWithdraw = false; 
    bool public isComplete;


    ExampleExternalContract public exampleExternalContract;
    
    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    modifier notCompleted(){
        isComplete = exampleExternalContract.completed();
        require(isComplete == false);
        _;
    }

  
    function stake() public payable{ 
        require(currentState == State.StakingPeriod && !openForWithdraw, "Contract not open for staking");
        require(msg.value > 0, "Sem fundos para o staking"); 
        balances[msg.sender] += msg.value; 

        emit NewStake(msg.sender, msg.value); 
    } 

    
    function execute() notCompleted public {
     
        require(currentState == State.StakingPeriod && block.timestamp > deadline, "Can only execute once after deadline");

        
        if (address(this).balance >= threshold) {
          
            exampleExternalContract.complete{value: address(this).balance}();
            currentState = State.Success;
        } else {
            
            openForWithdraw = true;
            currentState = State.Withdraw;
        }
    }

  
    function withdraw() notCompleted public {
        require(currentState == State.Withdraw && openForWithdraw, "Contract not open for withdrawal");
        require(balances[msg.sender] > 0, "No funds staked to withdraw");

        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

  
    function timeLeft() public view returns(uint){
        uint256 remainingTime = deadline > block.timestamp ? deadline - block.timestamp : 0;

        return remainingTime;
    }
    receive() external payable{
        stake();
    }    
}
