const fs = require('fs')

const SafeMath = artifacts.require(
  'openzeppelin-solidity/contracts/math/SafeMath.sol'
)

const ChildChain = artifacts.require('./ChildChain.sol')
const ECVerify = artifacts.require('./lib/ECVerify.sol')

module.exports = async function(deployer, network, accounts) {
  deployer.then(async() => {
    console.log(`network: ${network}`)
    await deployer.deploy(SafeMath)
    await deployer.link(SafeMath, ChildChain)
      
    await deployer.deploy(ECVerify)
    await deployer.link(ECVerify, ChildChain)

    await deployer.deploy(ChildChain)

    let contractAddresses = fs.readFileSync('./build/contractAddresses.json').toString()
    contractAddresses = JSON.parse(contractAddresses)

    const childChain = await ChildChain.deployed()
    console.log('childChain.address', childChain.address)

    // add matic WETH
    const p = await childChain.addToken(
      accounts[0],
      contractAddresses.MaticWETH,
      'Matic WETH',
      'MTX',
      18,
      false // _isERC721
    )
    const evt = p.logs.find(log => {
      return log.event === 'NewToken'
    })
    contractAddresses['ChildWeth'] = evt.args.token

    // add root token
    const p = await childChain.addToken(
      accounts[0],
      contractAddresses.RootToken,
      'Token S',
      'STX',
      18,
      false // _isERC721
    )
    const evt = p.logs.find(log => {
      return log.event === 'NewToken'
    })
    contractAddresses['ChildToken'] = evt.args.token

    fs.writeFileSync(
      './build/contractAddresses.json',
      JSON.stringify(contractAddresses, null, 4) // Indent 4 spaces
    )
  })
}
