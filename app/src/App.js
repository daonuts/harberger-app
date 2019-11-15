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
  const { assets = [], syncing } = appState

  const [wizard, setWizard] = useState(false)
  const [screen, setScreen] = useState()

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
