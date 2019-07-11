pragma solidity ^0.5.2;

import { ERC721Full } from "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Validator is ERC721Full {
  // TODO: pull validator staking here
  //
  // Storage
  //
}


contract ValidatorContract is Ownable { // is rootchainable/stakeMgChainable
  uint256 public delegatedAmount;
  uint256[] public delegators;
  uint256 public rewards;
  address public validator;
  address public delegatorContract;
  bool delegation = true;

  // will be reflected after one WITHDRAWAL_DELAY/(some Period + upper lower cap)
  uint256 public rewardRatio;
  uint256 public slashingRatio;

  struct State {
    int256 amount;
    uint256 totalStake;
  }

  // keep state of each checkpoint and rewards
  mapping (uint256 => State) public delegationState;

  constructor (address _owner) public {
    validator = _owner;
  }

  modifier onlyDelegatorContract() {
    require(delegatorContract == msg.sender);
    _;
  }

  function register() public onlyOwner {

  }

  function updateRewards(uint256 amount, uint256 checkpoint, uint256 stake) public onlyOwner {
    rewards += amount;
    delegationState[checkpoint].amount = amount;
    delegationState[checkpoint].totalStake = delegatedAmount + stake;
  }

  function bond(uint256 delegatorId, uint256 amount) public onlyDelegatorContract {
    require(delegation);
    delegators.push(delegatorId);
    delegatedAmount += amount;
  }

  function unBond(uint256 delegatorId, uint256 index, uint256 amount) public onlyDelegatorContract {
    // update rewards according to rewardRatio
    require(delegators[index] == delegatorId);
    delegatedAmount -= amount;
    // start unbonding
    delegators[index] = delegators[delegators.length];
    delete delegators[delegators.length];
  }

  function unBondAllLazy(uint256 exitEpoch) public onlyOwner returns(bool) {
    delegation = false; //  won't be accepting any new delegations
    for (uint256 i; i < delegators.length; i++) {
      unBondLazy(delegators[i], exitEpoch);
    }
    return true;
  }

  function getRewards(uint256 delegatorId, uint256 delegationAmount, uint256 startEpoch, uint256 endEpoch) public onlyDelegatorContract retruns(uint256) {
    // distribute delegator rewards first
    // for each delegator reward, keep the rest
    // TODO: use struct as param
    uint256 reward = 0;
    for (uint256 epoch = startEpoch; epoch > endEpoch; epoch++) {
      if (delegationState[epoch].amount) {
        reward += (delegationState[epoch].amount * delegationAmount)/delegationState[epoch];
      }
    }
    return reward;
  }

  function slash() public onlyOwner {
    // slash delegator according to slashingRatio
  }

}



  }