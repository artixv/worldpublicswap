// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.05.18

pragma solidity 0.8.6;

library structlibrary {
    struct reserve{
        address[2]  assetAddr;
        uint[2]     reserve;           
        uint[2]     priceCumulative;
        uint        totalSupply;
        uint        a0;
        uint8       category; 
        uint32      balanceFee;
    }

    struct reserveInOrOut{       
        uint[2]     priceCumulative;
        uint[2]     reserve;
    }

    struct exVaults{
        address[] tokens;
        uint      amountIn;
        uint      amountOut;
        uint      Limits;
    }

}