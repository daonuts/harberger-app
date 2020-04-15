import 'core-js/stable'
import 'regenerator-runtime/runtime'
import AragonApi from '@aragon/api'
import { NULL_ADDRESS } from './utils'

const api = new AragonApi()
let account

api.store(
  async (state, event) => {
    let newState, asset, assets, from, to

    // console.log(event.event, state.assets)

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
          assets = state.assets.concat(asset)
        } else if(to === NULL_ADDRESS) {
          // is burn
          asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
          assets = replace(state.assets, asset)
        } else {
          // is normal transfer (new owner, price, etc)
          asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
          assets = replace(state.assets, asset)
        }
        newState = {...state, assets }
        break
      case 'Balance':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        asset.expiration = new Date(event.returnValues._expiration*1000)
        newState = {...state, assets: replace(state.assets, asset)}
        break
      case 'Price':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, assets: replace(state.assets, asset)}
        break
      case 'OwnerURI':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, assets: replace(state.assets, asset)}
        break
      case 'Tax':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, assets: replace(state.assets, asset)}
        break
      case 'MetaURI':
        asset = await marshalAsset(parseInt(event.returnValues._tokenId, 10))
        newState = {...state, assets: replace(state.assets, asset)}
        break
      case 'DEBUG':
        console.log(event.returnValues)
        newState = state
        break
      default:
        newState = state
    }

    return newState
  },
  {
    init: async function(cachedState){
      return {
        assets: [],
        ...cachedState
      }
    }
  }
)

async function marshalAsset(id){
  const { active, owner, tax, lastPaymentDate, price, balance, ownerURI, metaURI } = await api.call('assets', id).toPromise()
  return { id, owner, tax, lastPaymentDate, price, balance, ownerURI, metaURI }
}

function replace(items, item, key = 'id'){
  let idx = items.findIndex(i=>i[key]===item[key])
  items.splice(idx, 1, {...item})
  return items
}
