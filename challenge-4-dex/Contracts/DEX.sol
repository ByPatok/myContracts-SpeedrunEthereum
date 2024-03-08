// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this challenge. Also return variable names need to be specified exactly may be referenced (It may be helpful to cross reference with front-end code function calls).
 */
contract DEX {
	/* ========== GLOBAL VARIABLES ========== */

	IERC20 token; //instantiates the imported contract

	/* ========== EVENTS ========== */

	/**
	 * @notice Emitted when ethToToken() swap transacted
	 */
	event EthToTokenSwap(
		address swapper,
		uint256 tokenOutput,
		uint256 ethInput
	);

	/**
	 * @notice Emitted when tokenToEth() swap transacted
	 */
	event TokenToEthSwap(
		address swapper,
		uint256 tokensInput,
		uint256 ethOutput
	);

	/**
	 * @notice Emitted when liquidity provided to DEX and mints LPTs.
	 */
	event LiquidityProvided(
		address liquidityProvider,
		uint256 liquidityMinted,
		uint256 ethInput,
		uint256 tokensInput
	);

	/**
	 * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
	 */
	event LiquidityRemoved(
		address liquidityRemover,
		uint256 liquidityWithdrawn,
		uint256 tokensOutput,
		uint256 ethOutput
	);

	/* ========== MAPPING ========== */
	mapping(address => uint256) public liquidity; //maps the address of the liquidity provider to the amount of liquidity they have provided

	/* ========== STATE VARIABLES ========== */
	uint public totalLiquidity; //total liquidity in the DEX

	/* ========== CONSTRUCTOR ========== */

	constructor(address token_addr) {
		token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
	}


	/* ========== MUTATIVE FUNCTIONS ========== */

	/**
	 * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
	 * @param tokens amount to be transferred to DEX
	 * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
	 * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
	 */
	function init(uint256 tokens) public payable returns (uint256) {
		// require totalLiquidity to be 0
		require(totalLiquidity == 0, "DEX: Already initialized");
		// set totalLiquidity to be the balance of the contract
		totalLiquidity = address(this).balance;
		liquidity[msg.sender] = totalLiquidity;
		require(token.transferFrom(msg.sender, address(this), tokens), "init: Transfer failed");
		return totalLiquidity;

	}

	/**
	 * @notice returns yOutput, or yDelta for xInput (or xDelta)
	 * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
	 */
	 // Price curve function 
	function price(
		uint256 xInput,
		uint256 xReserves,
		uint256 yReserves
	) public pure returns (uint256 yOutput) {
		// yOutput = (xInput * yReserves) / (xReserves + xInput)
		yOutput = (xInput * yReserves) / (xReserves + xInput);
		uint xInputWithfee = xInput * 997;
		uint numerator = xInputWithfee * yReserves;
		uint denominator = xReserves * 1000 + xInputWithfee;
		return numerator / denominator;
	}

	/**
	 * @notice returns liquidity for a user.
	 * NOTE: this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
	 * NOTE: if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
	 * NOTE: if you will be submitting the challenge make sure to implement this function as it is used in the tests.
	 */
	function getLiquidity(address lp) public view returns (uint256) {
		return liquidity[lp];
	}

	/**
	 * @notice sends Ether to DEX in exchange for $BAL
	 */
	function ethToToken() public payable returns (uint256 tokenOutput) {
		// I would not use require but instead a if and check user balance, but this is fine for the challenge.
		require(msg.value > 0, "msg.value must be greater than 0");
		// calculate reserves of both assets
		uint eth_reserve = address(this).balance - msg.value;
		uint token_reserve = token.balanceOf(address(this)); 
		// calculate tokenOutput
		tokenOutput = price(msg.value, eth_reserve, token_reserve);
		// Approve $BAL to be spent by DEX
		token.approve(address(this), tokenOutput);
		// transfer token to sender
		require(token.transfer(msg.sender, tokenOutput), "ethToToken: Transfer failed");
		// emit EthToTokenSwap event
		emit EthToTokenSwap(msg.sender, tokenOutput, msg.value);
		return tokenOutput;
	}

	/**
	 * @notice sends $BAL tokens to DEX in exchange for Ether
	 */
	function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
		// I would not use require but instead a if and check user balance, but this is fine for the challenge.
		require(tokenInput > 0, "tokenInput must be greater than 0");
		uint token_reserve = token.balanceOf(address(this));
		// calculate ethOutput
		ethOutput = price(tokenInput, token_reserve, address(this).balance);
		// transfer tokens to DEX
		require(token.transferFrom(msg.sender, address(this), tokenInput), "tokenToEth: Transfer failed");
		// transfer ethOutput to msg.sender
		(bool sent, ) = msg.sender.call{value: ethOutput}("");
		require(sent, "tokenToEth: revert in transferring eth");
		// emit TokenToEthSwap event
		emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
		return ethOutput;
	}

	/**
	 * @notice allows deposits of $BAL and $ETH to liquidity pool
	 * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
	 * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
	 * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
	 */

	function deposit() public payable returns (uint256 tokensDeposited) {
		// I would not use require but instead a if and check user balance, but this is fine for the challenge.
		require(msg.value > 0, "msg.value must be greater than 0");
		uint ethReserve = address(this).balance - msg.value;
		uint tokenReserve = token.balanceOf(address(this));
		
		// calculate tokenDeposit and liquidityMinted, then update liquidity[msg.sender] and totalLiquidity
		uint tokenDeposit = (msg.value * tokenReserve / ethReserve) + 1;
		uint liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
		liquidity[msg.sender] += liquidityMinted;
		totalLiquidity += msg.value;

		// transfer eth to DEX, approve $BAL to be spent by DEX, and transfer tokenDeposit to DEX
		token.approve(address(this), tokenDeposit);
		require(token.transferFrom(msg.sender, address(this), tokenDeposit), "Transfer failed");
		emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);
		return tokenDeposit;
	}

	/**
	 * @notice allows withdrawal of $BAL and $ETH from liquidity pool
	 * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
	 */
	function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {
		// require liquidity[msg.sender] to be greater or equal to amount
		require(liquidity[msg.sender] >= amount, "Insufficient liquidity");
		// calculate eth_amount and token_amount, then transfer eth_amount and token_amount to msg.sender
		// Equation: x = (amount * DesiredUnitsReserve) / totalLiquidity)
		uint ethWithdrawn = (amount * address(this).balance) / totalLiquidity;
		uint tokenAmount = (amount * token.balanceOf(address(this))) / totalLiquidity;

		// transfer eth to DEX, approve $BAL to be spent by DEX, and transfer tokenDeposit to DEX
		(bool sent, ) = payable(msg.sender).call{value: ethWithdrawn}("");
		require(sent, "Withdrawn(): revert in transferring eth");
		token.approve(address(this), tokenAmount);
		token.transfer(msg.sender, tokenAmount);

		// update liquidity[msg.sender] and totalLiquidity
		liquidity[msg.sender] -= amount;
		totalLiquidity -= amount;
		emit LiquidityRemoved(msg.sender, amount, tokenAmount, ethWithdrawn);
		return (ethWithdrawn, tokenAmount);	
	}

}
