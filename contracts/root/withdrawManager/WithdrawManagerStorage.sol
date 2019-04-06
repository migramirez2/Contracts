pragma solidity ^0.5.2;

import { Registry } from '../Registry.sol';
// import { RootChain } from '../RootChain.sol';
import { ProxyStorage } from '../../common/misc/ProxyStorage.sol';


contract WithdrawManagerStorage is ProxyStorage {
  /**
   * Hardcode constants to save gas
   * bytes4 constant internal WITHDRAW_SIGNATURE = keccak256('withdraw(uint256)')
   * bytes4 constant internal TRANSFER_SIGNATURE = keccak256('transfer(address,uint256)')
   * bytes4 constant internal TRANSFER_SIGNATURE = keccak256('transferFrom(address,adress,uint256)')
   * bytes32 constant internal TRANSFER_SIGNATURE = keccak256('Withdraw(address,address,uint256,uint256,uint256)')
   */
  bytes4 constant internal WITHDRAW_SIGNATURE = 0x2e1a7d4d;
  bytes4 constant internal TRANSFER_SIGNATURE = 0xa9059cbb;
  bytes4 constant internal TRANSFER_SIGNATURE_ERC721 = 0x23b872dd;
  bytes32 constant internal WITHDRAW_EVENT_SIGNATURE = 0xebff2602b3f468259e1e99f613fed6691f3a6526effe6ef3e768ba7ae7a36c4f;

  bytes public constant networkId = "\x0d";
  
  Registry internal registry;
  // RootChain internal rootChain;
}
