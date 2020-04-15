import React, { useState, useEffect } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  AppBar, AppView, Button, Card, CardLayout, Checkbox, Field, GU, Header, IconArrowRight,
  Info, Main, Modal, SidePanel, Text, TextInput, theme
} from '@aragon/ui'
import BigNumber from 'bignumber.js'

const ipfsGateway = location.hostname === 'localhost' ? 'http://localhost:8080/ipfs' : 'https://ipfs.eth.aragon.network/ipfs'

function Assets({assets, onSelect}){
  return (
    <section>
      <h2 size="xlarge">Assets:</h2>
      <CardLayout columnWidthMin={30 * GU} rowHeight={250}>
        {assets.map((a, i)=><AssetCard {...a} key={a.id} onSelect={onSelect} />)}
      </CardLayout>
    </section>
  )
}

// function AssetCard({id, tax, owner, price, balance, ownerURI, metaURI, meta, onSelect}){
function AssetCard({id, tax, owner, price, balance, expiration, ownerURI, metaURI, onSelect}){
  const { api, connectedAccount } = useAragonApi()
  const [buyerOpen, setBuyerOpen] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [isOwner, setIsOwner] = useState()
  useEffect(()=>{
    setIsOwner(connectedAccount === owner)
  },[owner, connectedAccount])

  const [meta, setMeta] = useState()
  useEffect(()=>{
    if(!metaURI) return
    console.log("here")
    fetch(`${ipfsGateway}/${metaURI.split(':')[1]}`)
      .then(res=>res.json())
      .then(setMeta)
  }, [])

  return (
    <Card css={`
        display: grid;
        grid-template-columns: 100%;
        grid-template-rows: auto 1fr auto auto;
        grid-gap: ${1 * GU}px;
        padding: ${3 * GU}px;
        cursor: pointer;
    `} onClick={()=>onSelect(id)}>
      <header style={{display: "flex", justifyContent: "space-between"}}>
        <Text color={theme.textTertiary}>#{id}</Text>
        {meta && <Text color={theme.textPrimary}>{meta.name}</Text>}
        <IconArrowRight color={theme.textTertiary} />
      </header>
      <section>
        {meta && <Text color={theme.textPrimary}>{meta.description}</Text>}
      </section>
      <footer>
        {isOwner &&
          <Info>You own this asset</Info>
        }
        {!isOwner &&
          <Button mode="strong" emphasis="positive">{`Buy for ${BigNumber(price).div("1e+18").toFixed()}`}</Button>
        }
      </footer>
    </Card>
  )
}

export default Assets
