// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title YieldFarm
 * @dev A yield farming contract where users can stake ERC-20 tokens to earn rewards.
 * It includes support for boosting rewards with NFTs and a referral system.
 */
contract YieldFarm is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Struct to store staking information for each user
    struct StakeInfo {
        uint256 amount;      // Amount of tokens staked
        uint256 rewardDebt;  // Reward debt for calculating pending rewards
        uint256 lockUntil;   // Timestamp until which the stake is locked
    }

    // Struct to store information about each staking pool
    struct PoolInfo {
        IERC20Upgradeable stakingToken;  // Token to be staked
        IERC20Upgradeable rewardToken;   // Token given as reward
        uint256 rewardRate;              // Rate at which rewards are distributed
        uint256 lockDuration;            // Duration for which stakes are locked
        uint256 totalStaked;             // Total amount of tokens staked in this pool
        uint256 accRewardPerShare;       // Accumulated rewards per share, scaled by 1e12
        uint256 lastRewardTime;          // Last time rewards were distributed
    }

    PoolInfo[] public poolInfo;  // Array to store all pool information
    mapping(uint256 => mapping(address => StakeInfo)) public poolStakes;  // Mapping of pool ID to user address to stake info
    mapping(address => address) public referrers;  // Mapping of user address to their referrer's address
    mapping(address => uint256) public referralRewards;  // Mapping of user address to their referral rewards

    uint256 public baseRewardRate;    // Base rate for reward calculation
    uint256 public maxMultiplier;     // Maximum multiplier for rewards
    uint256 public multiplierDuration;  // Duration over which the multiplier increases
    uint256 public nftBoostRate;      // Boost rate for holding NFTs
    uint256 public referralBonus;     // Bonus for referring new users
    uint256 public refereeBonus;      // Bonus for being referred
    bool public paused;               // Flag to pause the contract in case of emergencies

    IERC721Upgradeable public nftToken;  // NFT token for boost mechanism
    IERC20Upgradeable public governanceToken;  // Governance token of the protocol

    // Events
    event Staked(address indexed user, uint256 indexed pid, uint256 amount, uint256 lockUntil);
    event Unstaked(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 indexed pid, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ReferrerSet(address indexed user, address indexed referrer);
    event PoolAdded(uint256 indexed pid, address stakingToken, address rewardToken, uint256 rewardRate, uint256 lockDuration);

    // Modifier to prevent functions from being called while the contract is paused
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    /**
     * @dev Initializes the contract with initial values
     * @param _governanceToken Address of the governance token
     * @param _nftToken Address of the NFT token for boost mechanism
     * @param _baseRewardRate Base rate for reward calculation
     * @param _maxMultiplier Maximum multiplier for rewards
     * @param _multiplierDuration Duration over which the multiplier increases
     * @param _nftBoostRate Boost rate for holding NFTs
     * @param _referralBonus Bonus for referring new users
     * @param _refereeBonus Bonus for being referred
     */
    function initialize(
        IERC20Upgradeable _governanceToken,
        IERC721Upgradeable _nftToken,
        uint256 _baseRewardRate,
        uint256 _maxMultiplier,
        uint256 _multiplierDuration,
        uint256 _nftBoostRate,
        uint256 _referralBonus,
        uint256 _refereeBonus
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        governanceToken = _governanceToken;
        nftToken = _nftToken;
        baseRewardRate = _baseRewardRate;
        maxMultiplier = _maxMultiplier;
        multiplierDuration = _multiplierDuration;
        nftBoostRate = _nftBoostRate;
        referralBonus = _referralBonus;
        refereeBonus = _refereeBonus;
    }

    /**
     * @dev Adds a new staking pool
     * @param _stakingToken Address of the token to be staked
     * @param _rewardToken Address of the token given as reward
     * @param _rewardRate Rate at which rewards are distributed
     * @param _lockDuration Duration for which stakes are locked
     */
    function addPool(
        IERC20Upgradeable _stakingToken,
        IERC20Upgradeable _rewardToken,
        uint256 _rewardRate,
        uint256 _lockDuration
    ) external onlyOwner {
        poolInfo.push(PoolInfo({
            stakingToken: _stakingToken,
            rewardToken: _rewardToken,
            rewardRate: _rewardRate,
            lockDuration: _lockDuration,
            totalStaked: 0,
            accRewardPerShare: 0,
            lastRewardTime: block.timestamp
        }));
        emit PoolAdded(poolInfo.length - 1, address(_stakingToken), address(_rewardToken), _rewardRate, _lockDuration);
    }

    /**
     * @dev Allows a user to stake tokens in a specific pool
     * @param _pid Pool ID
     * @param _amount Amount of tokens to stake
     */
    function stake(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Cannot stake 0");

        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage userStake = poolStakes[_pid][msg.sender];
        _updatePool(_pid);
        _updateRewards(_pid, msg.sender);

        pool.stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        userStake.amount += _amount;
        userStake.lockUntil = block.timestamp + pool.lockDuration;
        pool.totalStaked += _amount;

        emit Staked(msg.sender, _pid, _amount, userStake.lockUntil);
    }

    /**
     * @dev Allows a user to unstake tokens from a specific pool
     * @param _pid Pool ID
     * @param _amount Amount of tokens to unstake
     */
    function unstake(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage userStake = poolStakes[_pid][msg.sender];
        require(userStake.amount >= _amount, "Insufficient staked amount");
        require(block.timestamp >= userStake.lockUntil, "Stake is still locked");

        _updatePool(_pid);
        _updateRewards(_pid, msg.sender);

        userStake.amount -= _amount;
        pool.totalStaked -= _amount;

        pool.stakingToken.safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _pid, _amount);
    }

    /**
     * @dev Allows a user to claim their rewards from a specific pool
     * @param _pid Pool ID
     */
    function claimReward(uint256 _pid) external nonReentrant {
        _updatePool(_pid);
        _updateRewards(_pid, msg.sender);
        uint256 reward = poolStakes[_pid][msg.sender].rewardDebt;
        poolStakes[_pid][msg.sender].rewardDebt = 0;

        poolInfo[_pid].rewardToken.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, _pid, reward);
    }

    /**
     * @dev Allows a user to emergency withdraw their stake without caring about rewards
     * @param _pid Pool ID
     */
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage userStake = poolStakes[_pid][msg.sender];
        require(userStake.amount > 0, "No staked amount");

        uint256 amount = userStake.amount;
        userStake.amount = 0;
        userStake.rewardDebt = 0;

        pool.totalStaked -= amount;
        pool.stakingToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    /**
     * @dev Allows a user to set their referrer
     * @param _referrer Address of the referrer
     */
    function setReferrer(address _referrer) external {
        require(referrers[msg.sender] == address(0), "Referrer already set");
        require(_referrer != msg.sender, "Cannot refer yourself");
        referrers[msg.sender] = _referrer;
        referralRewards[_referrer] += referralBonus;
        referralRewards[msg.sender] += refereeBonus;
        emit ReferrerSet(msg.sender, _referrer);
    }

    /**
     * @dev Allows the owner to set the reward rate for a specific pool
     * @param _pid Pool ID
     * @param _rewardRate New reward rate
     */
    function setRewardRate(uint256 _pid, uint256 _rewardRate) external onlyOwner {
        poolInfo[_pid].rewardRate = _rewardRate;
    }

    /**
     * @dev Allows the owner to set the lock duration for a specific pool
     * @param _pid Pool ID
     * @param _lockDuration New lock duration
     */
    function setLockDuration(uint256 _pid, uint256 _lockDuration) external onlyOwner {
        poolInfo[_pid].lockDuration = _lockDuration;
    }

    /**
     * @dev Allows the owner to set the NFT boost rate
     * @param _nftBoostRate New NFT boost rate
     */
    function setNftBoostRate(uint256 _nftBoostRate) external onlyOwner {
        nftBoostRate = _nftBoostRate;
    }

    /**
     * @dev Allows the owner to distribute governance tokens
     * @param _user Address of the user to receive tokens
     * @param _amount Amount of tokens to distribute
     */
    function distributeGovernanceTokens(address _user, uint256 _amount) external onlyOwner {
        governanceToken.safeTransfer(_user, _amount);
    }

    /**
     * @dev Allows the owner to pause the contract
     */
    function pause() external onlyOwner {
        paused = true;
    }

    /**
     * @dev Allows the owner to unpause the contract
     */
    function unpause() external onlyOwner {
        paused = false;
    }

    /**
     * @dev Calculates the reward multiplier based on staking duration
     * @param stakedDuration Duration for which tokens have been staked
     * @return Calculated multiplier
     */
    function _calculateRewardMultiplier(uint256 stakedDuration) internal view returns (uint256) {
        uint256 multiplier = stakedDuration / multiplierDuration;
        return multiplier > maxMultiplier ? maxMultiplier : multiplier;
    }

    /**
     * @dev Updates the reward variables of the given pool
     * @param _pid Pool ID
     */
    function _updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.totalStaked > 0) {
            uint256 multiplier = block.timestamp - pool.lastRewardTime;
            uint256 reward = multiplier * pool.rewardRate;
            pool.accRewardPerShare += (reward * 1e12) / pool.totalStaked;
        }
        pool.lastRewardTime = block.timestamp;
    }

    /**
     * @dev Updates the reward variables for a user on the given pool
     * @param _pid Pool ID
     * @param _user Address of the user
     */
    function _updateRewards(uint256 _pid, address _user) internal {
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage userStake = poolStakes[_pid][_user];
        if (userStake.amount > 0) {
            uint256 pendingReward = (userStake.amount * pool.accRewardPerShare) / 1e12 - userStake.rewardDebt;
            uint256 stakedDuration = block.timestamp - (userStake.lockUntil - pool.lockDuration);
            uint256 multiplier = _calculateRewardMultiplier(stakedDuration);
            pendingReward = pendingReward * (baseRewardRate + multiplier) / baseRewardRate;
            userStake.rewardDebt = pendingReward;
            if (nftToken.balanceOf(_user) > 0) {
                userStake.rewardDebt += pendingReward * nftBoostRate / 100;
            }
        }
    }
}