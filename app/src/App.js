import React, { useState, useEffect } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  Button, Card, CardLayout, Checkbox, Field, GU, Header, IconArrowRight,
  Info, Main, Modal, SidePanel, Text, TextInput, theme
} from '@aragon/ui'
import AssetDetail from './AssetDetail'
import Assets from './Assets'
import NewAsset from './NewAsset'

const ipfsGateway = location.hostname === 'localhost' ? 'http://localhost:8080/ipfs' : 'https://ipfs.eth.aragon.network/ipfs'

export default function App() {
  const { api, network, appState, connectedAccount } = useAragonApi()
  const { rawAssets = [], syncing } = appState

  const [wizard, setWizard] = useState(false)
  const [screen, setScreen] = useState()

  const [assets, setAssets] = useState([])
  useEffect(()=>{
    if(!rawAssets || !rawAssets.length) return
    if(!assets.length) setAssets(rawAssets)
    Promise.all(rawAssets.map(async (a)=>{
      let ipfsHash
      if(!a.meta && a.metaURI) {
        ipfsHash = a.metaURI.split(':')[1]
        if(ipfsHash)
          a.meta = await (await fetch(`${ipfsGateway}/${ipfsHash}`)).json()
      }
      let ownerOf = await api.call("ownerOf", a.id).toPromise()
      console.log("ownerOf", ownerOf)
      let tax = await api.call("taxDue", a.id).toPromise()
      console.log("tax", tax)
      // let numDays = await api.call("numDays", a.id).toPromise()
      // console.log("numDays", numDays)
      console.log(a)
      setAssets(rawAssets.slice())
    }))
  }, [rawAssets])

  const [selectedId, setSelectedId] = useState()
  const [selected, setSelected] = useState()
  useEffect(()=>{
    setSelected(assets.find(a=>a.id==selectedId))
  }, [assets, selectedId])

  return (
    <Main>
      <Header primary="Harberger" secondary={<Button mode="strong" emphasis="positive" onClick={()=>setWizard(true)}>New asset</Button>} />
      { wizard
        ? <NewAsset onBack={()=>setWizard()} />
        : selected
          ? <AssetDetail {...selected} onBack={()=>setSelectedId()} />
          : <Assets assets={assets} onSelect={setSelectedId} />
      }
    </Main>
  )
}
