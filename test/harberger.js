const Harberger = artifacts.require("Harberger");
const ethers = require('ethers');
const { utils } = ethers
const { toUtf8Bytes, hexlify, hexZeroPad, bigNumberify } = utils

contract('Harberger', (accounts) => {

  context('extract buy parameters', async () => {

    let harberger

    before(async () => {
        harberger = await Harberger.new()
    })

    it('extract buy parameters', async () => {
      const decimals = "1000000000000000000"
      const newPrice = bigNumberify(1000).mul(decimals)
      const credit = bigNumberify(140).mul(decimals)
      const contentURI = toUtf8Bytes("peaches")
      console.log(hexlify(contentURI))
      const args = "0x" +
                      [hexlify(1)]
                      .concat( [1, newPrice, credit].map(hexlify).map(a=>hexZeroPad(a,32)) )
                      .concat( hexlify(contentURI) )
                      .map(a=>a.substr(2)).join("")
      console.log(args)

      const params = await harberger.extractBuyParameters(args)
      console.log(params)

      // assert.equal(controller, accounts[0], "token controller wasn't first account");
    });

  })

});
