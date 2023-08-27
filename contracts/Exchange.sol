// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public tokenAddress;

    constructor(address token) ERC20("ETH TOKEN LP Token", "lpETHTOKEN") {
        require(token != address(0), "Null address passed for Token address");
        tokenAddress = token;
    }

    // returns the balance of tokens in the contract
    function getReserve() public view returns (uint256) {
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    function addLiquidity(uint256 amountOfToken)
        public
        payable
        returns (uint256)
    {
        uint256 lpTokensToMint; // for rewarding the market makers
        uint256 ethReserveBalance = address(this).balance;
        uint256 tokenReserveBalance = getReserve();

        ERC20 token = ERC20(tokenAddress);

        // if the reserve is empty, acceot any user supplied
        // value for initial liquidity

        if (tokenReserveBalance == 0) {
            // tranfer token from the user to the contract
            token.transferFrom(msg.sender, address(this), amountOfToken);

            //lpTokensToMint = ethReserveBalance = msg.value
            lpTokensToMint = ethReserveBalance;

            //mint LP tokens to the user
            _mint(msg.sender, lpTokensToMint);

            return lpTokensToMint;
        }

        // If the reserve is not empty. calculate amt of LP tokens to be
        // minted

        uint256 ethReservePriorToFunctionCall = ethReserveBalance - msg.value;
        uint256 minTokenAmountRequired = (msg.value * tokenReserveBalance) /
            ethReservePriorToFunctionCall;

        require(
            amountOfToken >= minTokenAmountRequired,
            "Insufficient amount of token provided"
        );

        // semd the required amount of tokens to the exchange contract
        token.transferFrom(msg.sender, address(this), minTokenAmountRequired);

        // how many lp tokens to be minted?
        lpTokensToMint =
            (totalSupply() * msg.value) /
            ethReservePriorToFunctionCall;

        _mint(msg.sender, lpTokensToMint);

        return lpTokensToMint;
    }

    function removeLiquidity(uint256 amountOfLPTokens) public returns (uint256, uint256) {
        require(
            amountOfLPTokens > 0,
            "Amount of tokens to be removed must be greater than zero"
        );

        uint256 ethReserveBalance = address(this).balance;
        uint256 lpTokenTotalSupply = totalSupply();

        uint256 ethToReturn = (ethReserveBalance * amountOfLPTokens) / lpTokenTotalSupply;
        uint256 tokensToReturn = (getReserve()*amountOfLPTokens) / lpTokenTotalSupply;

        _burn(msg.sender, amountOfLPTokens);
        payable(msg.sender).transfer(ethToReturn);
        ERC20(tokenAddress).transfer(msg.sender, tokensToReturn);
        
        return (ethToReturn, tokensToReturn);
    }

    // xy = (x+dx)(y-dy)--> CPMM ( Constant Product Market Maker )
    function getOutputAmountFromSwap(
        uint256 inputAmount, // dx, outputAmount = dy
        uint256 inputReserve, // x
        uint256 outputReserve // y
    )   public pure returns(uint256) {
            require(
                inputReserve > 0 && outputReserve > 0,
                "Reserves must be positive"
            );

            uint256 inputAmountWithFee = inputAmount * 99;

            uint256 numerator = inputAmountWithFee * outputReserve;
            uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

            return numerator / denominator;
    }

    function ethToTokenSwap(uint256 minTokensToReceive) public payable {
        uint256 tokenReserveBalance = getReserve();
        uint256 tokensToReceive = getOutputAmountFromSwap(
            msg.value,
            address(this).balance - msg.value,
            tokenReserveBalance
        );

        require(
            tokensToReceive >= minTokensToReceive,
            "Tokens received are less than minimum tokens expected"
        );

        ERC20(tokenAddress).transfer(msg.sender, tokensToReceive);
    }

    // tokenToEthSwap allows users to swap tokens for ETH
    function tokenToEthSwap(
        uint256 tokensToSwap,
        uint256 minEthToReceive
    ) public {
        uint256 tokenReserveBalance = getReserve();
        uint256 ethToReceive = getOutputAmountFromSwap(
            tokensToSwap,
            tokenReserveBalance,
            address(this).balance
        );

        require(
            ethToReceive >= minEthToReceive,
            "ETH received is less than minimum ETH expected"
        );

        ERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokensToSwap
        );

        payable(msg.sender).transfer(ethToReceive);
    }

}
