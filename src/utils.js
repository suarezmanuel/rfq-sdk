import { createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import { mendoza } from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString, ExpirationTime } from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt } from "@arkiv-network/sdk/query"

const DEFAULT_EXPIRATION_TIME = ExpirationTime.fromHours(24);

async function createEntity(
  walletClient,
  payload,
  contentType,
  attributes = [],
  expiresIn = DEFAULT_EXPIRATION_TIME,
) {
  // Ensure 'type' attribute is always included
  const hasTypeAttribute = attributes.some(attr => attr.key === 'type' && attr.value === 'browser-wallet');
  if (!hasTypeAttribute) {
    attributes.push({ key: 'type', value: 'browser-wallet' });
  }
  const { entityKey, txHash } = await walletClient.createEntity({
    payload: stringToPayload(payload),
    contentType: contentType,
    attributes: attributes,
    expiresIn: expiresIn,
  });
  return { entityKey, txHash };
}

// make the entities numbered somehow?
// buy fromAmount of fromToken for an unknown amount of toToken
// ExpirationTime.fromHours(24)
async function createBuyEntity(walletClient, fromToken, toToken, fromAmount, expiresIn=DEFAULT_EXPIRATION_TIME) {
  return createEntity(
      walletClient, 
      `buy ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 
      'text/plain', 
      [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx-type', value: 'buy' }],
      expiresIn
    );
}

// sell fromAmount of fromToken for an unknown amount of toToken
async function createSellEntity(walletClient, fromToken, toToken, fromAmount, expiresIn=DEFAULT_EXPIRATION_TIME) {
  return createEntity(walletClient, `sell ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 'text/plain', [{ key: 'app_id', value: 'myapp-id' }, { key: 'tx_type', value: 'sell' }], expiresIn);
}

// fetch all entities owned by lookupAddress
// filter=[{key: 'app_id', value: 'my-app-id'}, {key: 'tx_type', value: 'buy'}]
async function fetchUserEntities(publicClient, lookupAddress, limit=undefined, attributes=[]) {
  const entities = await publicClient.fetchEntities({
    creator: lookupAddress,
    attributes: attributes,
    limit: limit,
  });
  return entities;
}

// delete the entity with the given entityKey, maybe the user regrets deploying the trade
// do we need another function for when the trade is successful?
async function deleteEntity(publicClient, entityKey) {
  await publicClient.deleteEntity(entityKey);
}

// fetch info e.g. owner, fromToken, toToken, fromAmount.
async function fetchEntityInformation(publicClient, entityKey) {
}

// called when entity is finalized, e.g. the trade is successful
async function finalizeEntity(entityKey) {
  console.log('trade successful');
}

async function getEntityData(publicClient, entityKey) {
  const entity = await publicClient.getEntity(entityKey);
  return bytesToString(entity.payload);
}

export { createEntity, createBuyEntity, createSellEntity, fetchUserEntities, getEntityData };