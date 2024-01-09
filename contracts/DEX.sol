// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.21;

import "./IDEX.sol";
import "./TokenCC.sol";

contract DEX is IDEX{
    uint public decimals;

    uint public k; //constant, aka x * y

    uint public x; //how much ether is in the pool in wei

    uint public y; //how many tokens are in the pool, returned with all the decimals

    uint public feeNumerator; //

    uint public feeDenominator;
    
    uint public feesEther; //fees accumulated in wei

    uint public feesToken; //fees accumulated for all addrsses, will have as many decimals as the token crypto

    mapping(address => uint) public etherLiquidityForAddress;//how much eth does a certain address have in the pool
  
    mapping(address => uint) public tokenLiquidityForAddress; //same as above except tcc

    address public etherPricer; //address of oracle

    address public ERC20Address; //address of erc20 token

    //variables not in interface:

    bool public poolCreated; //pool can only be created once, this is set to true once createPool is called

    TokenCC public token; //erc20 object

    IEtherPriceOracle public oracle; 

    bool internal adjustingLiquidity;
    

    constructor(){

    }
    function symbol() external view returns (string memory){
        require(poolCreated, "pool not created yet");
        return token.symbol();
    }   

    function getEtherPrice() external view returns (uint){
        require(poolCreated, "pool not created yet");
        return oracle.price();
    }

    function getTokenPrice() external view returns (uint){
        require(poolCreated, "pool not created yet");

        uint numTokens = y / 10 ** decimals;

        uint tokenPrice = (oracle.price() * (x / 10 ** 18)) / numTokens;
        return tokenPrice;
    }

    function getPoolLiquidityInUSDCents() external view returns (uint){
        require(poolCreated, "pool not created yet");
        uint currentETHPrice = oracle.price(); //in cents
        uint poolEtherPrice = currentETHPrice * (x / 10 ** 18);

        return poolEtherPrice * 2;
    }


    function createPool(uint _tokenAmount, uint _feeNumerator, uint _feeDenominator, address _erc20token, address _etherPricer) external payable{
        require(!poolCreated, "pool has already been created");
        poolCreated = true;
        
        token = TokenCC(_erc20token);
        oracle = IEtherPriceOracle(_etherPricer);

        ERC20Address = _erc20token;
        etherPricer = _etherPricer;
        decimals = token.decimals();
        token.transferFrom(msg.sender, address(this), _tokenAmount);

        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;

        k = _tokenAmount * msg.value;
        y = _tokenAmount;
        x = msg.value;
        adjustingLiquidity = false;

        emit liquidityChangeEvent();
    }

    function addLiquidity() external payable{
        require(poolCreated, "pool not created yet");
        //put 2 eth in
        //5 eth, 200 tcc in pool
        //rate is 1:40
        //return 80 tcc
        adjustingLiquidity = true;

        uint TCCToAdd = (msg.value * y) / x;

        require(TCCToAdd < token.allowance(msg.sender, address(this)), "tokens not allowed");
        
        require(token.transferFrom(msg.sender, address(this), TCCToAdd), "transfer failed");

        y += TCCToAdd;
        x += msg.value;

        k = x * y;
        etherLiquidityForAddress[msg.sender] += msg.value;
        tokenLiquidityForAddress[msg.sender] += TCCToAdd;

        adjustingLiquidity = false;
        emit liquidityChangeEvent();

    }

    function removeLiquidity(uint amountEther) external{ 
        require(poolCreated, "pool not created yet");
        require(etherLiquidityForAddress[msg.sender] <= amountEther, "you do not have enough ether in the pool");
        adjustingLiquidity = true;

        (bool success, ) = payable(msg.sender).call{value: amountEther}("");
        require (success, "payment didn't work");
        
        uint TCCToRemove = (amountEther * y) / x;

        token.transfer(msg.sender, TCCToRemove);

        etherLiquidityForAddress[msg.sender] -= amountEther;
        tokenLiquidityForAddress[msg.sender] -= TCCToRemove;

        x -= amountEther;
        y -= TCCToRemove;
        k = x * y;

        adjustingLiquidity = false;
        emit liquidityChangeEvent();

    }
    
    receive() external payable{ 
        require(poolCreated, "pool not created yet");
        
        uint etherValue = msg.value;
        x += etherValue; 

        uint NewTokenCCAmount = k / x; 

        uint tokenCCToReturn = y - NewTokenCCAmount; 
        
        require(y >= tokenCCToReturn, "not enough tokenCC to return");
        

        uint fees = (tokenCCToReturn * feeNumerator) / feeDenominator; 
        
        uint returnMinusFees = tokenCCToReturn - fees; 
        token.transfer(msg.sender, returnMinusFees);
        
        feesToken += fees; 
        y = NewTokenCCAmount;
        
        emit liquidityChangeEvent();

    
    }
    
    function onERC20Received(address from, uint amount, address erc20) external returns (bool){ //hard
        require(poolCreated, "pool not created yet");
        require(erc20 == address(token), "incorrect erc20 address was given");
        require(!adjustingLiquidity, "currently adjusting liquidity");
        require(amount <= token.allowance(from, address(this)), "tokens not allowed");
        require(y != 0, "no tokens in the pool");

        y += amount; 

        uint newEthAmount = k / y; 

        uint ethToReturn = x - newEthAmount;

        require(x >= ethToReturn, "not enough ETH to return");

        x = newEthAmount;

        uint fees = (ethToReturn * feeNumerator) / feeDenominator;

        uint returnMinusFees = ethToReturn - fees;

        (bool success, bytes memory result) = payable(from).call{value: returnMinusFees}("");
        require (success, string.concat("Payment to DEX didn't work: ", getRevertMsg(result)));

        feesEther += fees;

        emit liquidityChangeEvent();
        
        return true;

    }

    function getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68)
            return 'Transaction reverted silently';

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function setEtherPricer(address p) external{
        oracle = IEtherPriceOracle(p);
    }

    

    function getDEXinfo() external view returns (address, string memory, string memory, address, uint, uint, uint, uint, uint, uint, uint, uint){
        require(poolCreated, "pool not created yet");
        return (address(this), token.symbol(), token.name(), address(token), k, x, y, feeNumerator, feeDenominator, decimals, feesEther, feesToken);
    }

    function reset() external{
        revert();
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool){
        return interfaceId == type(IERC165).interfaceId || 
               interfaceId == type(IDEX).interfaceId || 
               interfaceId == type(IERC20Receiver).interfaceId;

    }


}
