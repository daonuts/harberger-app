const ethers = require('ethers');
const HarbergerABI = require('../abi/Harberger.json').abi
const TokenABI = require('../abi/Token.json').abi
const provider = new ethers.providers.Web3Provider(web3.currentProvider, 'rinkeby')
const {utils} = ethers;
const decimals = "1000000000000000000"

const harbergerAddress = "0x6ba5d1344e0c82a38463ae5e54fce3702486ca49"


async function main(){
  await ethereum.enable()
  const token = new ethers.Contract("0xeE41f12A18420D1C4726B024109d3F07D612a363", TokenABI,  provider.getSigner())
  const harberger = new ethers.Contract(harbergerAddress, HarbergerABI,  provider.getSigner())
  // console.log(utils.bigNumberify(1000).mul(decimals))
  let approveTx = await token.approve(harbergerAddress, utils.bigNumberify(1140).mul(decimals))
  await approveTx.wait()
  let buyTx = await harberger.buy("1", utils.bigNumberify(1000).mul(decimals), "", utils.bigNumberify(140).mul(decimals))
  await buyTx.wait()
}

main()
