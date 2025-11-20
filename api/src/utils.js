import { createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import { mendoza } from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString, ExpirationTime } from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt, lt, or } from "@arkiv-network/sdk/query"

const DEFAULT_EXPIRATION_TIME = ExpirationTime.fromHours(24);

async function createEntity(
  walletClient,
  payload,
  contentType,
  attributes = [],
  expiresIn = DEFAULT_EXPIRATION_TIME,
) {
  // Ensure 'type' attribute is always included
  if (!attributes.some(attr => attr.key === 'type' && attr.value === 'browser-wallet')) {
    attributes.push({ key: 'type', value: 'browser-wallet' });
  }
  if (!attributes.some(attr => attr.key === 'my_project' && attr.value === 'wins')) {
    attributes.push({ key: 'my_project', value: 'wins' });
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
// maybe add a limit to the requests extracted.
async function createBuyEntity(walletClient, fromAmount, fromToken, toToken, expiresIn=DEFAULT_EXPIRATION_TIME) {
  // we can maybe later display the txHash
  const { entityKey, txHash } = await createEntity(
      walletClient, 
      `buy ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 
      'text/plain', 
      [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'buy' }, { key: 'from_amount', value: fromAmount }, { key: 'from_token', value: fromToken }, { key: 'to_token', value: toToken}],
      expiresIn
    );
    return entityKey;
}
// sell fromAmount of fromToken for an unknown amount of toToken
async function createSellEntity(walletClient, fromToken, toToken, fromAmount, expiresIn=DEFAULT_EXPIRATION_TIME) {
    return createEntity(
        walletClient, 
        `sell ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 
        'text/plain',
        [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'sell' }, { key: 'from_amount', value: fromAmount }, { key: 'from_token', value: fromToken }, { key: 'to_token', value: toToken}],
        expiresIn
      );
}

async function fetchAllRequests(publicClient) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(or([eq('tx_type', 'buy'), eq('tx_type', 'sell')]))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

async function fetchRequestsFromUserBuy(publicClient, userPublicKey) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('tx_type', 'buy'))
  .ownedBy(userPublicKey)
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

async function fetchRequestsFromUserSell(publicClient, userPublicKey) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('tx_type', 'sell'))
  .ownedBy(userPublicKey)
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

// we need to change the 'where gt' if we want to do various tokens and filter by 1, and not only one token and filter by 1.
async function fetchRequestsFromToken(publicClient, fromToken="ETH") {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('from_token', fromToken))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

async function fetchRequestsFromTokenGTAmount(publicClient, fromToken="ETH", amount=1) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('from_token', fromToken))
  .where(gt('from_amount', amount))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

async function fetchRequestsFromTokenLTAmount(publicClient, fromToken="ETH", amount=1) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('from_token', fromToken))
  .where(lt('from_amount', amount))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}


// sell fromAmount of fromToken for an unknown amount of toToken
// parentRequestKey is the txHash of a sell/buy entity.
async function createOfferEntity(walletClient, parentRequestKey, toAmount, toToken, expiresIn=DEFAULT_EXPIRATION_TIME) {
  const { entityKey, txHash } = createEntity(
      walletClient, 
      `offerring ${toAmount} ${toToken} to ${parentRequestKey}`, 
      'text/plain',
      [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'offer' }, { key: 'parent_request', value: parentRequestKey}, { key: 'to_amount', value: toAmount }, { key: 'to_token', value: toToken}],
      expiresIn
    );
}

async function fetchOffersParent(publicClient, parentRequestKey) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('tx_type', 'offer'))
  .where(eq('parent_request', parentRequestKey))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}

async function fetchOffersParentToToken(publicClient, parentRequestKey, toToken="ETH") {
    const query = publicClient.buildQuery();
    const result = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(eq('parent_request', parentRequestKey))
    .where(eq('to_token', toToken))
    .withAttributes(true)
    .withPayload(true)
    .withMetadata(true)
    .fetch()
    return result.entities;
}





// $sequence is block number << 32
// $owner, $creator
// $key 
// $expiration is block numberv normal

// general de buy, general de sell, de un usuario. gt lt amount, fromToken, toToken
// general de un usuario, how does time work, and how do i fetch amount of token?

// fetch all entities owned by lookupAddress
// filter=[{key: 'app_id', value: 'my-app-id'}, {key: 'tx_type', value: 'buy'}]
async function fetchUserEntities(publicClient, lookupAddress, limit=undefined, attributes=[]) {
  const query = publicClient.buildQuery();
  let builder = query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .ownedBy(lookupAddress)
    .withAttributes(true)
    .withPayload(true)
    .withMetadata(true);
  
  // Add attribute filters if provided
  attributes.forEach(attr => {
    builder = builder.where(eq(attr.key, attr.value));
  });
  
  if (limit) {
    builder = builder.limit(limit);
  }
  
  const result = await builder.fetch();
  return result.entities;
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

async function getEntity(publicClient, entityKey) {
  const entity = await publicClient.getEntity(entityKey);
  // return bytesToString(entity.payload);
  return entity;
}

export { createEntity, createBuyEntity, createSellEntity, fetchUserEntities, getEntity, fetchAllRequests, fetchRequestsFromToken, fetchRequestsFromTokenGTAmount, fetchRequestsFromTokenLTAmount, createOfferEntity, fetchOffersParent, fetchOffersParentToToken, fetchRequestsFromUserBuy, fetchRequestsFromUserSell}