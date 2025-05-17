// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.05.18

pragma solidity 0.8.6;
interface ixVaults{
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function getCoinToStableLpPair(address tokenA) external view returns (address pair);
    function getLpPrice(address _lp) external view returns (uint );
    function getLpReserve(address _lp) external view returns (uint[2] memory ,uint[2] memory, uint);
    function getLpPair(address _lp) external view returns (address[2] memory);
    function getLpSettings(address _lp) external view returns(uint32 balanceFee, uint a0);

    function addTokenApproveToLpManager(address _token) external ;

    function creatLpVault(address _lp,address[2] memory _tokens,uint8 lpCategory) external;
    function increaseLpAmount(address _lp,uint[2] memory _reserveIn,uint _lpAdd) external;
    function dereaseLpAmount(address _lp,uint[2] memory _reserveOut,uint _lpDel) external;
    function lpSettings(address _lp,uint32 _balanceFee, uint _a0) external;

    function xexchange(address[] memory tokens,uint amountIn,uint amountOut,uint limits,uint deadline) external returns(uint);
}