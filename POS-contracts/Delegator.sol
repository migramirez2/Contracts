pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import { StakeManager } from "./StakeManager.sol";
import { ValidatorContract } from "./Validator.sol";


contract Delegator is ERC721Full {
  event Bonding(uint256 indexed delegatorId, uint256 indexed validatorId);
  event UnBonding(uint256 indexed delegatorId, uint256 indexed validatorId);
  event ReStaked(uint256 indexed delegatorId,uint256 indexed amount);

  ERC20 public token;
  uint256 public NFTCounter = 1;
  uint256 public MIN_DEPOSIT_SIZE = 0;
  uint256 public totalStaked;
  StakeManager public stakeManager; // Todo: replace in calls like current Epoch

  struct Delegator {
    uint256 activationEpoch;
    uint256 deactivationEpoch;
    uint256 amount;
    uint256 reward;
    uint256 bondedTo;
    bytes data; // meta data
  }

  //deligator metadata
  mapping (uint256 => Delegator) public delegators;

  // only delegator
  modifier onlyDelegator(uint256 delegatorId) {
    require(ownerOf(delegatorId) == msg.sender);
    _;
  }

  constructor (stakeManager _stakeManager) ERC721Full("Matic Delegator", "MD") public {
    stakeManager = _stakeManager;
  }

  function getRewards(uint256 delegatorId) public onlyDelegator(delegatorId) {
    address validator;
    (,,,,,validator) = stakeManager.validators(delegators[delegatorId].bondedTo);
    ValidatorContract(validator).getRewards(delegatorId);
  }

  function bond(uint256 delegatorId, uint256 validatorId) public onlyDelegator(delegatorId) {
    // add into timeline for next checkpoint
    address validator;
    (,,,,,validator) = stakeManager.validators(validatorId);
    ValidatorContract(validator).bond(delegatorId);
    delegators[delegatorId].bondedTo = validatorId;
  }

  function unBond(uint256 delegatorId) public onlyDelegator(delegatorId) {
    address validator;
    (,,,,,validator) = stakeManager.validators(delegators[delegatorId].bondedTo);
    ValidatorContract(validator).unBond(delegatorId);
    delegators[delegatorId].bondedTo = 0;
  }

  function reStake(uint256 delegatorId) public onlyDelegator(delegatorId) {
    delegators[delegatorId].amount += delegators[delegatorId].reward;
    emit ReStaked(delegatorId, delegators[delegatorId].reward);
    delegators[delegatorId].reward = 0;
  }

  function stake(uint256 amount) public {
    stakeFor(msg.sender, amount);
  }

  function stakeFor(address user, uint256 amount) public onlyWhenUnlocked {
    require(balanceOf(user) == 0, "No second time staking");
    require(amount >= stakeManager.MIN_DEPOSIT_SIZE());

    require(token.transferFrom(msg.sender, address(this), amount), "Transfer stake");
    totalStaked = totalStaked.add(amount);

    delegators[NFTCounter] = Delegator({
      reward: 0,
      activationEpoch: currentEpoch,
      amount: amount,
      data: "0x0"
      });

    _mint(user, NFTCounter);
    emit Staked(user, NFTCounter, currentEpoch, amount, totalStaked);
    NFTCounter = NFTCounter.add(1);
  }

  function unstake(uint256 delegatorId) public onlyDelegator(delegatorId) {
    if (!delegators[delegatorId].bondedTo) {
      unBond();
    }
    delegators[delegatorId].deactivationEpoch = currentEpoch;
    emit UnstakeInit(delegatorId, msg.sender, delegators[delegatorId].amount, currentEpoch);
  }

  function unstakeClaim(uint256 delegatorId) public onlyDelegator(delegatorId) {
    // can only claim stake back after WITHDRAWAL_DELAY
    require(delegators[delegatorId].deactivationEpoch.add(stakeManager.WITHDRAWAL_DELAY()) <= currentEpoch);
    uint256 amount = delegators[delegatorId].amount;
    totalStaked = totalStaked.sub(amount);

    // TODO :add slashing here use soft slashing in slash amt variable
    _burn(msg.sender, delegatorId);

    require(token.transfer(msg.sender, amount + delegators[delegatorId].reward)); // Todo safeMath
    emit Unstaked(msg.sender, delegatorId, amount, totalStaked);
  }

}
