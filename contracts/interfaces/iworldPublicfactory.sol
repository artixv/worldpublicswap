// SPDX-License-Identifier: Business Source License 1.1
// First Release Time : 2025.05.18
pragma solidity 0.8.6;

interface iworldPublicFactory {

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function getCoinToStableLpPair(address tokenA) external view returns (address pair);
    function allLpPairs(uint) external view returns (address pair);
    function allLpPairsLength() external view returns (uint);
    function getLpPairsDetails(address pair) external view returns (address[2] memory,uint8);
    function createPair(address tokenA, address tokenB) external returns (address pair);

}
