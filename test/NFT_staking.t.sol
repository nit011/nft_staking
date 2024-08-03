// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployNFTStaking} from "../script/NFT_staking.s.sol";
import {NFTStaking} from "../src/NFT_staking.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTStakingTest is StdCheats, Test {
    NFTStaking public nftStaking;
    IERC721Enumerable public nft;
    IERC20 public rewardToken;

    address public constant USER = address(1);
    uint256 public constant REWARD_RATE = 10;
    uint256 public constant UNBONDING_PERIOD = 1 weeks;
    uint256 public constant REWARD_DELAY_PERIOD = 1 days;
    uint256 public constant TOKEN_ID = 1;

    function setUp() external {
        DeployNFTStaking deployer = new DeployNFTStaking();
        nftStaking = deployer.run();

        nft = IERC721Enumerable(nftStaking.nft());
        rewardToken = IERC20(nftStaking.rewardToken());

        vm.deal(USER, 10 ether);
    }

    function testStakeNFT() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        nftStaking.stakeNFT(tokenIds);
        vm.stopPrank();

        (uint256 stakedAt,, bool unbonding,) = nftStaking.stakes(USER, TOKEN_ID);
        assert(stakedAt > 0);
        assert(!unbonding);
    }

    function testUnstakeNFT() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        nftStaking.stakeNFT(tokenIds);
        nftStaking.unstakeNFT(tokenIds);
        vm.stopPrank();

        (, , bool unbonding,) = nftStaking.stakes(USER, TOKEN_ID);
        assert(unbonding);
    }

    function testWithdrawNFT() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        nftStaking.stakeNFT(tokenIds);
        nftStaking.unstakeNFT(tokenIds);
        vm.warp(block.timestamp + UNBONDING_PERIOD);
        nftStaking.withdrawNFT(TOKEN_ID);
        vm.stopPrank();

        (uint256 stakedAt, , , ) = nftStaking.stakes(USER, TOKEN_ID);
        assert(stakedAt == 0);
    }

    function testClaimRewards() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        nftStaking.stakeNFT(tokenIds);
        vm.warp(block.timestamp + REWARD_DELAY_PERIOD);
        nftStaking.claimRewards();
        vm.stopPrank();
        uint256 rewardBalance = rewardToken.balanceOf(USER);
        assert(rewardBalance > 0);
    }

    function testPauseAndUnpause() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        vm.stopPrank();
        nftStaking.pause();
        vm.startPrank(USER);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        vm.expectRevert("Pausable: paused");
        nftStaking.stakeNFT(tokenIds);
        vm.stopPrank();
        nftStaking.unpause();
        vm.startPrank(USER);
        nftStaking.stakeNFT(tokenIds);
        vm.stopPrank();
        (uint256 stakedAt,, bool unbonding,) = nftStaking.stakes(USER, TOKEN_ID);
        assert(stakedAt > 0);
        assert(!unbonding);
    }

    function testUpdateRewardRate() public {
        vm.startPrank(USER);
        nft.approve(address(nftStaking), TOKEN_ID);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        nftStaking.stakeNFT(tokenIds);
        vm.warp(block.timestamp + 1 days);

        uint256 oldRewardRate = nftStaking.rewardRate();
        uint256 newRewardRate = 20;
        nftStaking.setRewardRate(newRewardRate);
        vm.warp(block.timestamp + 1 days); 

        nftStaking.claimRewards();
        vm.stopPrank();

        uint256 rewardBalance = rewardToken.balanceOf(USER);
        uint256 expectedReward = 1 days * oldRewardRate + 1 days * newRewardRate;
        assert(rewardBalance == expectedReward);
    }

    function testUpdateUnbondingPeriod() public {
        uint256 newUnbondingPeriod = 2 weeks;
        nftStaking.setUnbondingPeriod(newUnbondingPeriod);
        assert(nftStaking.unbondingPeriod() == newUnbondingPeriod);
    }

    function testUpdateRewardDelayPeriod() public {
        uint256 newRewardDelayPeriod = 2 days;
        nftStaking.setRewardDelayPeriod(newRewardDelayPeriod);
        assert(nftStaking.rewardDelayPeriod() == newRewardDelayPeriod);
    }
}
