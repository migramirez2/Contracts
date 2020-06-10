pragma solidity ^0.5.2;

import {ERC20NonTransferable} from "../../common/tokens/ERC20NonTransferable.sol";
import {ERC20} from "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import {StakingInfo} from "./../StakingInfo.sol";
import {OwnableLockable} from "../../common/mixin/OwnableLockable.sol";
import {IStakeManager} from "../stakeManager/IStakeManager.sol";
import {IValidatorShare} from "./IValidatorShare.sol";
import {Initializable} from "../../common/mixin/Initializable.sol";

contract ValidatorShare is IValidatorShare, ERC20NonTransferable, OwnableLockable, Initializable {
    struct Delegator {
        uint256 shares;
        uint256 withdrawEpoch;
    }

    uint256 constant EXCHANGE_RATE_PRECISION = 100;
    uint256 constant REWARD_PRECISION = 10**25;

    StakingInfo public stakingLogger;
    IStakeManager public stakeManager;
    uint256 public validatorId;
    uint256 public minAmount = 10**18;

    uint256 public totalStake;
    uint256 rewardPerShare;
    // uint256 public activeAmount;
    bool public delegation = true;

    uint256 public withdrawPool;
    uint256 public withdrawShares;

    mapping(address => uint256) public amountStaked;
    mapping(address => Delegator) public delegators;
    mapping(address => uint256) public initalRewardPerShare;

    modifier onlyValidator() {
        require(stakeManager.ownerOf(validatorId) == msg.sender, "not validator");
        _;
    }

    // onlyOwner will prevent this contract from initializing, since it's owner is going to be 0x0 address
    function initialize(uint256 _validatorId, address _stakingLogger, address _stakeManager) external initializer  {
        validatorId = _validatorId;
        stakingLogger = StakingInfo(_stakingLogger);
        stakeManager = IStakeManager(_stakeManager);
        _transferOwnership(_stakeManager);

        minAmount = 10**18;
        delegation = true;
    }

    function exchangeRate() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        return
            totalShares == 0
                ? EXCHANGE_RATE_PRECISION
                : stakeManager.delegatedAmount(validatorId).mul(EXCHANGE_RATE_PRECISION).div(totalShares);
    }

    function withdrawExchangeRate() public view returns (uint256) {
        uint256 _withdrawShares = withdrawShares;
        return
            _withdrawShares == 0
                ? EXCHANGE_RATE_PRECISION
                : withdrawPool.mul(EXCHANGE_RATE_PRECISION).div(_withdrawShares);
    }

    function buyVoucher(uint256 _amount, uint256 _minSharesToMint) public onlyWhenUnlocked {
        require(delegation, "Delegation is disabled");

        uint256 rate = exchangeRate();
        uint256 shares = _amount.mul(EXCHANGE_RATE_PRECISION).div(rate);
        require(shares >= _minSharesToMint, "Too much slippage");
        require(delegators[msg.sender].shares == 0, "Ongoing exit");

        _withdrawAndTransferRewards();

        _mint(msg.sender, shares);
        
        _amount = _amount.sub(_amount % rate.mul(shares).div(EXCHANGE_RATE_PRECISION));

        totalStake = totalStake.add(_amount);
        amountStaked[msg.sender] = amountStaked[msg.sender].add(_amount);
        require(stakeManager.delegationDeposit(validatorId, _amount, msg.sender), "deposit failed");

        initalRewardPerShare[msg.sender] = getRewardPerShare();

        StakingInfo logger = stakingLogger;
        logger.logShareMinted(validatorId, msg.sender, _amount, shares);
        logger.logStakeUpdate(validatorId);
    }

    function sellVoucher(uint256 _minClaimAmount) public {
        uint256 shares = balanceOf(msg.sender);
        require(shares > 0, "Zero balance");

        uint256 rate = exchangeRate();
        uint256 _amount = rate.mul(shares).div(EXCHANGE_RATE_PRECISION);
        require(_amount >= _minClaimAmount, "Too much slippage");

        _burn(msg.sender, shares);
        stakeManager.updateValidatorState(validatorId, -int256(_amount));

        _withdrawAndTransferRewards();

        uint256 _withdrawPoolShare = _amount.mul(EXCHANGE_RATE_PRECISION).div(withdrawExchangeRate());

        withdrawPool = withdrawPool.add(_amount);
        withdrawShares = withdrawShares.add(_withdrawPoolShare);
        delegators[msg.sender] = Delegator({shares: _withdrawPoolShare, withdrawEpoch: stakeManager.epoch()});
        amountStaked[msg.sender] = 0;

        StakingInfo logger = stakingLogger;
        logger.logShareBurned(validatorId, msg.sender, _amount, shares);
        logger.logStakeUpdate(validatorId);
    }

    function _withdrawAndTransferRewards() private returns(uint256) {
        uint256 currentRewardPerShare = _commitRewardPerShare(msg.sender);
        uint256 liquidRewards = _calculateReward(msg.sender, currentRewardPerShare);
        if (liquidRewards >= minAmount) {
            require(stakeManager.transferFunds(validatorId, liquidRewards, msg.sender), "Insufficent rewards");
        }

        return liquidRewards;
    }

    function withdrawRewards() public {
        uint256 rewards = _withdrawAndTransferRewards();
        require(rewards >= minAmount, "Too small rewards amount");
        stakingLogger.logDelegatorClaimRewards(validatorId, msg.sender, rewards);
    }

    function restake() public {
        /**
            restaking is simply buying more shares of pool
            but those needs to be nonswapable/transferrable to prevent https://en.wikipedia.org/wiki/Tragedy_of_the_commons

            - only active amount is considers as active stake
            - move reward amount to active stake pool
            - no shares are minted
        */
        uint256 currentRewardPerShare = _commitRewardPerShare(msg.sender);
        uint256 liquidRewards = _calculateReward(msg.sender, currentRewardPerShare);
        require(liquidRewards >= minAmount, "Too small rewards to restake");

        amountStaked[msg.sender] = amountStaked[msg.sender].add(liquidRewards);
        initalRewardPerShare[msg.sender] = getRewardPerShare();
        totalStake = totalStake.add(liquidRewards);
        stakeManager.updateValidatorState(validatorId, int256(liquidRewards));

        StakingInfo logger = stakingLogger;
        logger.logStakeUpdate(validatorId);
        logger.logDelegatorRestaked(validatorId, msg.sender, amountStaked[msg.sender]);
    }

    function _commitRewardPerShare(address user) private returns(uint256) {
        uint256 _rewardPerShare = _calculateRewardPerShareWithRewards(stakeManager.withdrawAccumulatedReward(validatorId));
        rewardPerShare = _rewardPerShare;
        return _rewardPerShare;
    }

    function getLiquidRewards(address user) public view returns (uint256) {
        return _calculateReward(user, getRewardPerShare());
    }

    function getRewardPerShare() public view returns(uint256) {
        return _calculateRewardPerShareWithRewards(stakeManager.accumulatedReward(validatorId));
    }

    function _calculateRewardPerShareWithRewards(uint256 accumulatedReward) private view returns(uint256) {
        uint256 _rewardPerShare = rewardPerShare;
        if (accumulatedReward > 0) {
            _rewardPerShare = _rewardPerShare.add(
                accumulatedReward.mul(REWARD_PRECISION).div(totalSupply())
            );
        }

        return _rewardPerShare;
    }

    function _calculateReward(
        address user, 
        uint256 _rewardPerShare
    ) private view returns(uint256) {
        uint256 shares = balanceOf(user);
        if (shares == 0) {
            return 0;
        }

        return _rewardPerShare.sub(initalRewardPerShare[user]).mul(shares).div(REWARD_PRECISION);
    }

    function unstakeClaimTokens() public {
        Delegator storage delegator = delegators[msg.sender];

        uint256 shares = delegator.shares;
        require(
            delegator.withdrawEpoch.add(stakeManager.withdrawalDelay()) <= stakeManager.epoch() && shares > 0,
            "Incomplete withdrawal period"
        );

        uint256 _amount = withdrawExchangeRate().mul(shares).div(EXCHANGE_RATE_PRECISION);
        withdrawShares = withdrawShares.sub(shares);
        withdrawPool = withdrawPool.sub(_amount);

        totalStake = totalStake.sub(_amount);

        require(stakeManager.transferFunds(validatorId, _amount, msg.sender), "Insufficent rewards");
        stakingLogger.logDelegatorUnstaked(validatorId, msg.sender, _amount);
        delete delegators[msg.sender];
    }

    function slash(
        uint256 valPow, 
        uint256 delegatedAmount, 
        uint256 totalAmountToSlash
    ) external onlyOwner returns (uint256) {
        uint256 _withdrawPool = withdrawPool;
        uint256 delegationAmount = delegatedAmount.add(_withdrawPool);
        if (delegationAmount == 0) {
            return 0;
        }
        // total amount to be slashed from delegation pool (active + inactive)
        uint256 _amountToSlash = delegationAmount.mul(totalAmountToSlash).div(valPow.add(delegationAmount));
        uint256 _amountToSlashWithdrawalPool = _withdrawPool.mul(_amountToSlash).div(delegationAmount);

        // slash inactive pool
        withdrawPool = _withdrawPool.sub(_amountToSlashWithdrawalPool);
        stakeManager.decreaseValidatorDelegatedAmount(validatorId, _amountToSlash.sub(_amountToSlashWithdrawalPool));
        return _amountToSlash;
    }

    function updateDelegation(bool _delegation) external onlyOwner {
        delegation = _delegation;
    }

    function drain(
        address token,
        address payable destination,
        uint256 amount
    ) external onlyOwner {
        if (token == address(0x0)) {
            destination.transfer(amount);
        } else {
            require(ERC20(token).transfer(destination, amount), "Drain failed");
        }
    }
}
