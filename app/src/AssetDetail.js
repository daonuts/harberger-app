import React, { useState, useEffect } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  AddressField, AppBar, AppView, BackButton, Bar, Button, Card, CardLayout, Checkbox, Field, GU, Header, IconSettings,
  Info, Main, Modal, SidePanel, Table, TableCell, TableHeader, TableRow, Text, TextInput, theme
} from '@aragon/ui'
import BigNumber from 'bignumber.js'
import {abi as TokenABI} from '../../abi/Token.json'
import { ethers } from 'ethers'

function Asset({id, owner, tax, price, ownerURI="", credit, balance, onBack}){
  const { api, connectedAccount } = useAragonApi()

  const [newPrice, setNewPrice] = useState()
  useEffect(()=>{
    setNewPrice(BigNumber(price).div("1e+18").toFixed())
  }, [price])

  // const [newOwnerURI, setNewOwnerURI] = useState(ownerURI)
  // useEffect(()=>{ setNewOwnerURI(ownerURI) }, [ownerURI])

  const [isOwner, setIsOwner] = useState()
  useEffect(()=>{
    setIsOwner(connectedAccount === owner)
  },[owner, connectedAccount])

  const [newCredit, setNewCredit] = useState()
  useEffect(()=>{
    setNewCredit(calcTaxDue({tax, price: newPrice}, 14).toFixed())
  }, [newPrice])

  return (
    <React.Fragment>
      <Bar>
        <BackButton onClick={onBack} />
      </Bar>
      {isOwner
      ? <React.Fragment>
          <Info>You own this asset and can change certain parameters below</Info>
          <Field label="Tax rate:">
            <Text>{tax/1000}% per day</Text>
          </Field>
          <Field label="Current balance:">
            {BigNumber(balance).div("1e+18").toFixed()}
          </Field>
          <Field label="Change price:">
            <TextInput type="number" value={newPrice} onChange={(e)=>setNewPrice(e.target.value)} />
            <Button mode="outline" onClick={()=>api.setPrice(id, BigNumber(newPrice).times("1e+18").toFixed()).toPromise()}>Change</Button>
          </Field>
          {/*<Field label="Change owner uri:">
            <TextInput value={newOwnerURI} placeholder="ipfs:QmZP8YzJ5fDsk7nqtugfRzTgq38JsJUVxniJ3QCLgGyetd" onChange={(e)=>setNewOwnerURI(e.target.value)} />
            <Button mode="outline" onClick={()=>api.setOwnerURI(id, newOwnerURI).toPromise()}>Change</Button>
          </Field>*/}
          <Field label="Add to balance:">
            <PresetCreditButton id={id} price={price} tax={tax} days={7} />
            <PresetCreditButton id={id} price={price} tax={tax} days={14} />
            <PresetCreditButton id={id} price={price} tax={tax} days={28} />
          </Field>
          <Field label="Other amount:">
            <TextInput type="number" value={newCredit} onChange={(e)=>setNewCredit(e.target.value)} />
            <Button mode="outline" onClick={()=>doCredit(api, id, BigNumber(newCredit).times("1e+18"))}>Credit</Button>
          </Field>
        </React.Fragment>
      : <React.Fragment>
          <Info>You do not own this asset. You can buy it for {BigNumber(price).div("1e+18").toFixed()}.</Info>
          <Field label="Tax rate:">
            <Text>{tax/1000}% per day</Text>
          </Field>
          <Field label="New price:">
            <TextInput type="number" value={newPrice} onChange={(e)=>setNewPrice(e.target.value)} />
          </Field>
          {/*<Field label="New owner uri:">
            <TextInput placeholder="ipfs:QmbzeHmigWnheK5vP7VLJb77FNmzRGUmYaVGL5kS5oc9wM" value={newOwnerURI} onChange={(e)=>setNewOwnerURI(e.target.value)} />
          </Field>*/}
          <Field label="Start balance (min=1 day tax):">
            <TextInput type="number" value={newCredit} onChange={(e)=>setNewCredit(e.target.value)} />
          </Field>
          <Field>
            <Button mode="strong" emphasis="positive" onClick={(e)=>{e.stopPropagation();doBuy({api, id, price, newPrice, newCredit})}}>Buy</Button>
          </Field>
        </React.Fragment>
      }
      <hr />
      <AssetAdmin id={id} tax={tax} />
    </React.Fragment>
  )
}

function AssetAdmin({id, tax}){
  const { api } = useAragonApi()
  const [newTax, setNewTax] = useState(tax)
  useEffect(()=>{ setNewTax(tax/1000) }, [tax])

  return (
    <React.Fragment>
      <Info>The following actions may require advanced dao permissions.</Info>
      <Field label="Change tax:">
        <TextInput type="number" step="0.01" value={newTax} onChange={(e)=>setNewTax(e.target.value)} />
        <Button mode="outline" onClick={()=>api.setTax(id, Math.round(newTax*1000)).toPromise()}>Set</Button>
      </Field>
      <Field label="Delete this asset:">
        <Button mode="outline" emphasis="negative" onClick={()=>api.burn(id).toPromise()}>Delete</Button>
      </Field>
    </React.Fragment>
  )
}

function PresetCreditButton({ id, price, tax, days }){
  const { api } = useAragonApi()
  let amount = calcTaxDue({price, tax}, days)
  let text = `${BigNumber(amount).div("1e+18").toFixed()} (${days} day${days>1 ? 's' : ''})`
  return (
    <Button mode="outline" onClick={()=>doCredit(api, id, amount)}>{text}</Button>
  )
}

export default Asset

async function doBuy({api, id, price, newPrice, newOwnerURI, newCredit}){
  const { utils } = ethers
  const { hexlify, hexZeroPad, bigNumberify } = utils
  let tokenAddress = await api.call('currency').toPromise()

  let credit = BigNumber(newCredit).times("1e+18")
  let value = BigNumber(price).plus(credit)

  // let intentParams = {
  //   token: { address: tokenAddress, value: value.toFixed() }
  //   // gas: 2000000
  // }
  //
  // api.buy(id, BigNumber(newPrice).times("1e+18").toFixed(), '', credit.toFixed(), intentParams).toPromise()
  const decimals = "1000000000000000000"
  const { appAddress } = await api.currentApp().toPromise()
  console.log(appAddress)
  const token = api.external(tokenAddress, TokenABI)
  console.log(token)
  const args = "0x"+[id, bigNumberify(newPrice).mul(decimals), bigNumberify(credit.toFixed())].map(hexlify).map(a=>hexZeroPad(a,32)).map(a=>a.substr(2)).join("")
  console.log(args)
  const tx = await token.send(appAddress, value.toFixed(), args).toPromise()
  console.log(tx)
}

async function doCredit(api, id, amount){
  let tokenAddress = await api.call('currency').toPromise()
  let intentParams = {
    token: { address: tokenAddress, value: amount.toFixed() }
    // gas: 2000000
  }
  let onlyIfSelfOwned = true;

  api.credit(id, amount.toFixed(), onlyIfSelfOwned, intentParams).toPromise()
}

function calcTaxDue({price, tax}, days){
  price = BigNumber(price)
  tax = BigNumber(tax)
  let percent = BigNumber(100000)
  return BigNumber(days).times(price.times(tax).div(percent))
}
