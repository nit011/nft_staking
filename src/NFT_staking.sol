// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function 
// fallback function 
// external
// public
// internal
// private
// view & pure functions


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

///////////////////
// import
///////////////////

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract NFTStaking is  UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    ///////////////////
    // State Variables
    ///////////////////
    IERC721Enumerable public nft;
    IERC20 public rewardToken;
    uint256 public rewardRate;
    uint256 public unbondingPeriod;
    uint256 public rewardDelayPeriod;

    struct StakeInfo {
        uint256 stakedAt;
        uint256 rewardDebt;
        bool unbonding;
        uint256 unbondingStart;
    }

    mapping(address => mapping(uint256 => StakeInfo)) public stakes;
    mapping(address => mapping(uint256 => bool)) private stakedTokens;
    mapping(address => uint256) public rewardBalances;
    mapping(address => uint256) public lastClaimed;


    ///////////////////
    // Events
    ///////////////////
    event Staked(address indexed user, uint256 indexed tokenId);
    event Unstaked(address indexed user, uint256 indexed tokenId);
    event Claimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRewardRate);
    event UnbondingPeriodUpdated(uint256 newUnbondingPeriod);
    event RewardDelayPeriodUpdated(uint256 newRewardDelayPeriod);


    ///////////////////
    // Errors
    ///////////////////
    error NotTokenOwner();
    error AlreadyUnbonding();
    error NotInUnbondingPeriod();
    error UnbondingPeriodNotOver();
    error ClaimDelayPeriodNotMet();


    ///////////////////
    // modifier
    ///////////////////
    modifier onlyStaker(uint256 tokenId) {
        if (!stakedTokens[msg.sender][tokenId]) revert NotTokenOwner();
        _;
    }


   ///////////////////
   // Functions
   ///////////////////

    /**
     * @dev Initializes the contract with given parameters.
     * @param _nft Address of the NFT contract.
     * @param _rewardToken Address of the ERC20 reward token contract.
     * @param _rewardRate Number of reward tokens per block per NFT.
     * @param _unbondingPeriod Time in seconds for the unbonding period.
     * @param _rewardDelayPeriod Time in seconds for the reward delay period.
     */
    function initialize(
        address _nft,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _unbondingPeriod,
        uint256 _rewardDelayPeriod
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        nft = IERC721Enumerable(_nft);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        unbondingPeriod = _unbondingPeriod;
        rewardDelayPeriod = _rewardDelayPeriod;
    }


    ////////////////////////////
    // External Functions
    ////////////////////////////

     /**
     * @notice Stake multiple NFTs to earn rewards.
     * @dev Transfers the specified NFTs from the user to the contract.
     * @param nftIds Array of NFT token IDs to stake.
     */
    function stakeNFT(uint256[] calldata nftIds) external whenNotPaused nonReentrant {
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 tokenId = nftIds[i];
            if (nft.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
            nft.transferFrom(msg.sender, address(this), tokenId);

            StakeInfo storage stake = stakes[msg.sender][tokenId];
            stake.stakedAt = block.number;
            stake.rewardDebt = 0;
            stake.unbonding = false;

            stakedTokens[msg.sender][tokenId] = true;

            emit Staked(msg.sender, tokenId);
        }
    }
     
    /**
     * @notice Initiate the unbonding process for multiple staked NFTs.
     * @dev Marks the specified NFTs as unbonding.
     * @param nftIds Array of NFT token IDs to unstake.
     */
    function unstakeNFT(uint256[] calldata nftIds) external nonReentrant {
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 tokenId = nftIds[i];
            StakeInfo storage stake = stakes[msg.sender][tokenId];
            if (stake.unbonding) revert AlreadyUnbonding();
            stake.unbonding = true;
            stake.unbondingStart = block.timestamp;

            emit Unstaked(msg.sender, tokenId);
        }
    }


    /**
     * @notice Withdraw an NFT after the unbonding period has ended.
     * @dev Transfers the specified NFT back to the user if the unbonding period is over.
     * @param tokenId The NFT token ID to withdraw.
     */
    function withdrawNFT(uint256 tokenId) external onlyStaker(tokenId) nonReentrant {
        StakeInfo storage stake = stakes[msg.sender][tokenId];
        if (!stake.unbonding) revert NotInUnbondingPeriod();
        if (block.timestamp < stake.unbondingStart + unbondingPeriod) revert UnbondingPeriodNotOver();
        nft.transferFrom(address(this), msg.sender, tokenId);
        delete stakes[msg.sender][tokenId];
        delete stakedTokens[msg.sender][tokenId];
    }


      /**
     * @notice Claims the accumulated rewards.
     * @dev Users can claim their rewards after the reward delay period by calling this function.
     */
    function claimRewards() external nonReentrant {
        if (block.timestamp < lastClaimed[msg.sender] + rewardDelayPeriod) revert ClaimDelayPeriodNotMet();
        uint256 totalRewards = _calculateTotalRewards(msg.sender);
        rewardBalances[msg.sender] += totalRewards;
        rewardToken.transfer(msg.sender, totalRewards);
        lastClaimed[msg.sender] = block.timestamp;
        emit Claimed(msg.sender, totalRewards);
    }
     
    /**
     * @notice Pauses the contract.
     * @dev Only the owner can pause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }
    

    /**
     * @notice Unpauses the contract.
     * @dev Only the owner can unpause the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    

    /**
     * @notice Updates the reward rate.
     * @dev Only the owner can update the reward rate.
     * @param newRewardRate The new reward rate.
     */
     function setRewardRate(uint256 newRewardRate) external onlyOwner {
        _updateRewardDebts();
        rewardRate = newRewardRate;
        emit RewardRateUpdated(newRewardRate);
    }
    

    /**
     * @notice Updates the unbonding period.
     * @dev Only the owner can update the unbonding period.
     * @param newUnbondingPeriod The new unbonding period in seconds.
     */
    function setUnbondingPeriod(uint256 newUnbondingPeriod) external onlyOwner {
        unbondingPeriod = newUnbondingPeriod;
        emit UnbondingPeriodUpdated(newUnbondingPeriod);
    }
    

     /**
     * @notice Updates the reward delay period.
     * @dev Only the owner can update the reward delay period.
     * @param newRewardDelayPeriod The new reward delay period in seconds.
     */
    function setRewardDelayPeriod(uint256 newRewardDelayPeriod) external onlyOwner {
        rewardDelayPeriod = newRewardDelayPeriod;
        emit RewardDelayPeriodUpdated(newRewardDelayPeriod);
    }
     

    ////////////////////////////
    // Internal Functions
    ////////////////////////////

     /**
     * @dev Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    

     /**
     * @dev Calculates the total rewards for a user.
     * @param user The address of the user.
     * @return totalRewards The total rewards for the user.
     */
    function _calculateTotalRewards(address user) internal view returns (uint256) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < nft.balanceOf(user); i++) {
            uint256 tokenId = nft.tokenOfOwnerByIndex(user, i);
            if (stakedTokens[user][tokenId]) {
                StakeInfo storage stake = stakes[user][tokenId];
                if (!stake.unbonding) {
                    uint256 stakedDuration = block.number - stake.stakedAt;
                    uint256 reward = stakedDuration * rewardRate - stake.rewardDebt;
                    totalRewards += reward;
                }
            }
        }
        return totalRewards;
    }

     /**
     * @dev Updates the reward debts for all staked NFTs.
     */
    function _updateRewardDebts() internal {
        for (uint256 i = 0; i < nft.totalSupply(); i++) {
            address owner = nft.ownerOf(i);
            if (stakedTokens[owner][i]) {
                StakeInfo storage stake = stakes[owner][i];
                uint256 stakedDuration = block.number - stake.stakedAt;
                uint256 reward = stakedDuration * rewardRate - stake.rewardDebt;
                stake.rewardDebt += reward;
            }
        }
    }


}
