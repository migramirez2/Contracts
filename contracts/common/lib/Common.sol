pragma solidity ^0.5.2;

import "./BytesLib.sol";


library Common {
  function getV(bytes memory v, uint16 chainId) public pure returns (uint8) {
    if (chainId > 0) {
      return uint8(BytesLib.toUint(BytesLib.leftPad(v), 0) - (chainId * 2) - 8);
    } else {
      return uint8(BytesLib.toUint(BytesLib.leftPad(v), 0));
    }
  }

  //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) public view returns (bool) {
    uint length;
    assembly {
      //retrieve the size of the code on target address, this needs assembly
      length := extcodesize(_addr)
    }
    return (length > 0);
  }

  // convert uint256 to bytes
  function toBytes(uint256 _num) public pure returns (bytes memory _ret) {
    _ret = new bytes(32);
    assembly { mstore(add(_ret, 32), _num) }
  }

  // convert bytes to uint8
  function toUint8(bytes memory _arg) public pure returns (uint8) {
    return uint8(_arg[0]);
  }

  function toUint16(bytes memory _arg) public pure returns (uint16) {
    return (uint16(uint8(_arg[0])) << 8) | uint16(uint8(_arg[1]));
  }
}
