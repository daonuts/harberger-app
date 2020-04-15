const ethers = require('ethers');
const HarbergerABI = require('../abi/Harberger.json').abi
const TokenABI = require('../abi/Token.json').abi
const provider = ethers.getDefaultProvider()
const { utils } = ethers;
const { toUtf8Bytes, hexlify, hexZeroPad, bigNumberify } = utils
const decimals = "1000000000000000000"

const harbergerAddress = "0xc6cfc6a31e516d1622b80c0864b16f665712f89e"


async function main(){
  const harberger = new ethers.Contract(harbergerAddress, HarbergerABI,  provider)

  let exp = await harberger.balanceExpiration(1)

  console.log(new Date(exp.toNumber()*1000))

  let owner = await harberger.ownerOf(1)

  console.log(owner)

  let asset = await harberger.assets(1)

  console.log(asset, bigNumberify(asset.price).div(decimals).toString())

  let taxDue = await harberger.taxDue(1)

  console.log(taxDue)
}

main()
