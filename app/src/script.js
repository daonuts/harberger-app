import 'core-js/stable'
import 'regenerator-runtime/runtime'
import AragonApi from '@aragon/api'
import { NULL_ADDRESS } from './utils'

const api = new AragonApi()
let account

api.store(
  async (state, event) => {
    let newState, asset, rawAssets, from, to

    switch (event.event) {
      case 'ACCOUNTS_TRIGGER':
        account = event.returnValues.account
        newState = state
        break
      case 'Transfer':
        from = event.returnValues._from
        to = event.returnValues._to
        if(from === NULL_ADDRESS) {
          // is mint
          asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
          rawAssets = (state.rawAssets || []).concat(asset)
        } else if(to === NULL_ADDRESS) {
          // is burn
        } else {
          asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
          rawAssets = replace(state.rawAssets, asset)
        }
        newState = {...state, rawAssets }
        break
      case 'Balance':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, rawAssets: replace(state.rawAssets, asset)}
        break
      case 'Price':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, rawAssets: replace(state.rawAssets, asset)}
        break
      case 'OwnerURI':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, rawAssets: replace(state.rawAssets, asset)}
        break
      case 'Tax':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, rawAssets: replace(state.rawAssets, asset)}
        break
      case 'MetaURI':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, rawAssets: replace(state.rawAssets, asset)}
        break
      default:
        newState = state
    }

    return newState
  },
  {
    init: async function(){
      return {
        rawAssets: []
      }
    }
  }
)

async function marshalAsset(id){
  const { owner, tax, lastPaymentDate, price, balance, ownerURI, metaURI } = await api.call('assets', id).toPromise()
  return { id, owner, tax, lastPaymentDate, price, balance, ownerURI, metaURI }
}

function replace(items, item, key = 'id'){
  let idx = items.findIndex(i=>i[key]===item[key])
  items.splice(idx, 1, item)
  return items
}
