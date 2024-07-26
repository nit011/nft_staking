// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { NFTStaking } from "../src/NFT_staking.sol";

contract DeployNFTStaking is Script {
    address public nftAddress ; // set nft address
    address public rewardTokenAddress ; // set erc20 reward token address
    uint256 public rewardRate = 10; 
    uint256 public unbondingPeriod = 1 weeks;
    uint256 public rewardDelayPeriod = 1 days; 

    function run() external returns (NFTStaking) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        NFTStaking nftStaking = new NFTStaking();
        nftStaking.initialize(nftAddress, rewardTokenAddress, rewardRate, unbondingPeriod, rewardDelayPeriod);
        vm.stopBroadcast();
        return nftStaking;

    }
}
