const contracts = require('../contractAddresses.json')

const RootToken = artifacts.require('TestToken')
const StakeManager = artifacts.require('StakeManager')

async function stake(address, amount) {
  const accounts = await web3.eth.getAccounts()
  const stakeManager = await StakeManager.at(contracts.root.StakeManager)
  const rootToken = await RootToken.at(contracts.root.tokens.TestToken)
  console.log({ stakeManager: stakeManager.address, rootToken: rootToken.address })
  try {
    console.log('Sender accounts has a balanceOf', (await rootToken.balanceOf(accounts[0])).toString())
    await rootToken.approve(stakeManager.address, amount)
    console.log('approved, staking now...')
    await stakeManager.stakeFor(address, amount, address, false)
    console.log('staked')
  } catch (err) {
    console.log(err)
  }
}

module.exports = async function(callback) {
  const stakeFor = process.argv[6]
  const amount = web3.utils.toWei(process.argv[7])
  console.log(`Staking ${amount} for ${stakeFor}...`)
  await stake(stakeFor, amount)
  callback()
}
