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
async function createBuyEntity(walletClient, fromToken, toToken, fromAmount, expiresIn=DEFAULT_EXPIRATION_TIME) {
  return createEntity(
      walletClient, 
      `buy ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 
      'text/plain', 
      [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'buy' }, { key: 'from_amount', value: fromAmount }, { key: 'from_token', value: fromToken }, { key: 'to_token', value: toToken}],
      expiresIn
    );
}

// toToken
// fromToken 
// fromAmountGT
// fromAmountLT
// toAmountGT
// toAmountLT

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

// sell fromAmount of fromToken for an unknown amount of toToken
async function createOfferEntity(walletClient, fromToken, fromAmount, toToken, toAmount, expiresIn=DEFAULT_EXPIRATION_TIME) {
    return createEntity(
        walletClient, 
        `offer ${fromAmount} ${fromToken} for ${toAmount} ${toToken}`, 
        'text/plain',
        [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'offer' }, { key: 'from_amount', value: fromAmount }, { key: 'from_token', value: fromToken }, { key: 'to_amount', value: toAmount }, { key: 'to_token', value: toToken}],
        expiresIn
      );
}

async function fetchAllEntities(publicClient) {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    // .where(gt('created', 1763584400))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

async function fetchEntitiesFromTokenAmountLT(publicClient, fromTokenAmount=1) {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(lt('from_token', fromTokenAmount))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

async function fetchEntitiesFromTokenAmountGT(publicClient, fromTokenAmount=1) {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(gt('from_token', fromTokenAmount))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

async function fetchEntitiesToTokenAmountLT(publicClient, toTokenAmount=1) {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(lt('to_token', toTokenAmount))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

async function fetchEntitiesToTokenAmountGT(publicClient, toTokenAmount=1) {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(gt('to_token', toTokenAmount))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

async function fetchEntitiesToToken(publicClient, toToken="ETH") {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(gt('to_token', 0))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
}

// we need to change the 'where gt' if we want to do various tokens and filter by 1, and not only one token and filter by 1.
async function fetchEntitiesFromToken(publicClient, fromToken="ETH") {
    const query = publicClient.buildQuery();
    const entities = await query
    .where(eq('type', 'browser-wallet'))
    .where(eq('my_project', 'wins'))
    .where(gt('from_token', 0))
    .withAttributes(true)
    .withPayload(true)
    .fetch()
    return entities;
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

export { createEntity, createBuyEntity, createSellEntity, fetchUserEntities, getEntityData, fetchEntities };