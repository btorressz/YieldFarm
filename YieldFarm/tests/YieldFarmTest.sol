// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../contracts/YieldFarm.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title TestToken
 * @dev Simple ERC20 Token used for testing purposes
 */
contract TestToken is ERC20 {
    /**
     * @dev Constructor that mints an initial supply of tokens to the contract deployer.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialSupply The initial supply of tokens to be minted.
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

/**
 * @title TestNFT
 * @dev Simple ERC721 Token used for testing purposes
 */
contract TestNFT is ERC721 {
    uint256 public currentTokenId;

    /**
     * @dev Constructor that initializes the ERC721 token with a name and a symbol.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /**
     * @dev Function to mint a new NFT.
     * @param to The address to which the NFT will be minted.
     */
    function mint(address to) external {
        _mint(to, currentTokenId);
        currentTokenId++;
    }
}

/**
 * @title YieldFarmTest
 * @dev Test suite for the YieldFarm contract
 */
contract YieldFarmTest {
    TestToken public stakingToken;
    TestToken public rewardToken;
    TestNFT public nftToken;
    TestToken public governanceToken;
    YieldFarm public yieldFarm;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;

    /**
     * @dev Constructor that sets up the test environment, including token deployment and initial distribution.
     */
    constructor() {
        owner = msg.sender;
        user1 = address(0x1);
        user2 = address(0x2);

        stakingToken = new TestToken("Staking Token", "STK", INITIAL_SUPPLY);
        rewardToken = new TestToken("Reward Token", "RWD", INITIAL_SUPPLY);
        nftToken = new TestNFT("NFT Token", "NFT");
        governanceToken = new TestToken("Governance Token", "GOV", INITIAL_SUPPLY);

        yieldFarm = new YieldFarm();
        yieldFarm.initialize(
            IERC20Upgradeable(address(governanceToken)),
            IERC721Upgradeable(address(nftToken)),
            1e18, // baseRewardRate
            2, // maxMultiplier
            30 days, // multiplierDuration
            10, // nftBoostRate
            5, // referralBonus
            2 // refereeBonus
        );

        yieldFarm.addPool(
            IERC20Upgradeable(address(stakingToken)),
            IERC20Upgradeable(address(rewardToken)),
            1e18, // rewardRate
            1 // lockDuration (set to 1 second for testing purposes)
        );

        stakingToken.transfer(user1, 500000 * 10**18);
        rewardToken.transfer(user1, 500000 * 10**18);
    }

    /**
     * @dev Test the staking functionality of the YieldFarm contract.
     */
    function testStake() public {
        stakingToken.approve(address(yieldFarm), 1000 * 10**18);
        yieldFarm.stake(0, 1000 * 10**18);
        (uint256 amount, , uint256 lockUntil) = yieldFarm.poolStakes(0, address(this));
        require(amount == 1000 * 10**18, "Staked amount should be 1000 * 10**18");
        require(lockUntil > block.timestamp, "Lock duration should be in the future");
    }

    /**
     * @dev Test the unstaking functionality of the YieldFarm contract.
     */
    function testUnstake() public {
        stakingToken.approve(address(yieldFarm), 1000 * 10**18);
        yieldFarm.stake(0, 1000 * 10**18);

        // Wait for a short period
        uint256 i;
        for(i = 0; i < 10; i++) {
            // This loop is just to allow some time to pass
        }

        yieldFarm.unstake(0, 1000 * 10**18);
        (uint256 amount, , ) = yieldFarm.poolStakes(0, address(this));
        require(amount == 0, "Staked amount should be 0 after unstaking");
    }

    /**
     * @dev Test the reward claiming functionality of the YieldFarm contract.
     */
    function testClaimReward() public {
        stakingToken.approve(address(yieldFarm), 1000 * 10**18);
        yieldFarm.stake(0, 1000 * 10**18);

        // Wait for a short period
        uint256 i;
        for(i = 0; i < 10; i++) {
            // This loop is just to allow some time to pass
        }

        yieldFarm.claimReward(0);
        uint256 reward = rewardToken.balanceOf(address(this));
        require(reward > 0, "Reward not claimed");
    }

    /**
     * @dev Test the emergency withdrawal functionality of the YieldFarm contract.
     */
    function testEmergencyWithdraw() public {
        stakingToken.approve(address(yieldFarm), 1000 * 10**18);
        yieldFarm.stake(0, 1000 * 10**18);

        yieldFarm.emergencyWithdraw(0);
        (uint256 amount, , ) = yieldFarm.poolStakes(0, address(this));
        require(amount == 0, "Staked amount should be 0 after emergency withdraw");
    }

    /**
     * @dev Test the pause and unpause functionality of the YieldFarm contract.
     */
    function testPauseAndUnpause() public {
        yieldFarm.pause();
        
        bool success;
        (success, ) = address(yieldFarm).call(abi.encodeWithSignature("stake(uint256,uint256)", 0, 1000 * 10**18));
        require(!success, "Staking should fail when contract is paused");

        yieldFarm.unpause();
        stakingToken.approve(address(yieldFarm), 1000 * 10**18);
        yieldFarm.stake(0, 1000 * 10**18);
        (uint256 amount, , ) = yieldFarm.poolStakes(0, address(this));
        require(amount == 1000 * 10**18, "Staking should succeed when contract is unpaused");
    }

    /**
     * @dev Test the referral system functionality of the YieldFarm contract.
     */
    function testReferralSystem() public {
        yieldFarm.setReferrer(user2);
        address referrer = yieldFarm.referrers(address(this));
        require(referrer == user2, "Referrer should be set correctly");
    }
}
