const ethers = require('ethers');
const HarbergerABI = require('../abi/Harberger.json').abi
const TokenABI = require('../abi/Token.json').abi
const provider = new ethers.providers.Web3Provider(web3.currentProvider, 'rinkeby')
const { utils } = ethers;
const { toUtf8Bytes, hexlify, hexZeroPad, bigNumberify } = utils
const decimals = "1000000000000000000"

const harbergerAddress = "0x5024a25a6316c371114fdc91567dd1a635f4fa80"


async function main(){
  await ethereum.enable()
  const token = new ethers.Contract("0x9fBd0b013129B1C9C87cA10219BFa3f664B8D6F2", TokenABI,  provider.getSigner())
  const harberger = new ethers.Contract(harbergerAddress, HarbergerABI,  provider.getSigner())
  // console.log(utils.bigNumberify(1000).mul(decimals))
  // let approveTx = await token.approve(harbergerAddress, utils.bigNumberify(2280).mul(decimals))
  // await approveTx.wait()
  // let buyTx = await harberger.buy("1", utils.bigNumberify(2000).mul(decimals), "", utils.bigNumberify(280).mul(decimals))
  // await buyTx.wait()
  const assetId = 1
  const currentPrice = bigNumberify(1000).mul(decimals)
  const newCredit = bigNumberify(140).mul(decimals)
  const newPrice = bigNumberify(1000).mul(decimals)
  const value = currentPrice.add(newCredit)
  const newOwnerURI = ""    // not really used, so just placeholder for now

  const args = "0x" +
                  [hexlify(1)]    // 1 = buy
                  .concat( [assetId, newPrice, newCredit].map(hexlify).map(a=>hexZeroPad(a,32)) )
                  .concat( hexlify(toUtf8Bytes(newOwnerURI)) )
                  .map(a=>a.substr(2)).join("")

  console.log(await harberger.extractBuyParameters(args))         // can use to check parameters are ok
  // what this does is send the tokens to the harberger contract along with data (args) about what asset to buy
  const tx = await token.send(harbergerAddress, value, args)
}

main()
