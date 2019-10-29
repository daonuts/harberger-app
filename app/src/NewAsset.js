import React, { useState, useEffect } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  AppBar, AppView, BackButton, Bar, Button, Card, CardLayout, Checkbox, DropDown, Field, GU, Header, IconSettings,
  Info, Main, Modal, Radio, RadioGroup, SidePanel, Text, TextInput, theme
} from '@aragon/ui'
import BigNumber from 'bignumber.js'
import ipfsClient from 'ipfs-http-client'

function NewAirdrop({onBack}) {
  const { api, connectedAccount } = useAragonApi()
  const [tax, setTax] = useState(1)
  const [metaURI, setMetaURI] = useState("ipfs:QmZP8YzJ5fDsk7nqtugfRzTgq38JsJUVxniJ3QCLgGyetd")

  return (
    <React.Fragment>
      <Bar>
        <BackButton onClick={onBack} />
      </Bar>
      <Field label="Meta uri:">
        <TextInput value={metaURI} placeholder="ipfs:QmZP8YzJ5fDsk7nqtugfRzTgq38JsJUVxniJ3QCLgGyetd" onChange={(e)=>setMetaURI(e.target.value)} />
      </Field>
      <Field label="Asset tax (%/day):">
        <TextInput value={tax} type="number" step="0.01" onChange={(e)=>setTax(e.target.value)} />
      </Field>
      <Field>
        <Button onClick={()=>api.mint(metaURI, Math.round(tax*1000)).toPromise()}>Add asset</Button>
      </Field>
    </React.Fragment>
  )
}

export default NewAirdrop
