import { stringToPayload, ExpirationTime } from '@arkiv-network/sdk/utils'
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
// TODO: add the timestamps stuff, decide on expirationTime on frontend maybe

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
}
// sell fromAmount of fromToken for an unknown amount of toToken
async function createSellEntity(walletClient, fromAmount, fromToken, toToken, expiresIn=DEFAULT_EXPIRATION_TIME) {
  const { entityKey, txHash } = await createEntity(
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
// should receive walletClient.account
async function fetchRequestsFromUserBuy(publicClient, userPublicKey) {
  userPublicKey = typeof userPublicKey === 'string' ? userPublicKey : userPublicKey.address;
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('tx_type', 'buy'))
  .where(eq('$owner', userPublicKey))
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
  .where(eq('$owner', userPublicKey))
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
// parentRequestKey is the entityKey of a sell/buy entity.
// When an offer is created, ownership is transferred to the parent request owner
// so they can delete all offers when finalizing the request.
async function createOfferEntity(walletClient, publicClient, parentRequestKey, toAmount, toToken, expiresIn=DEFAULT_EXPIRATION_TIME) {

  const parentRequest = await publicClient.getEntity(parentRequestKey);
  const parentOwner = parentRequest.owner;
  
  const { entityKey, txHash } = await createEntity(
    walletClient, 
    `offerring ${toAmount} ${toToken} to ${parentRequestKey}`, 
    'text/plain',
    [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx_type', value: 'offer' }, { key: 'parent_request', value: parentRequestKey}, { key: 'to_amount', value: toAmount }, { key: 'to_token', value: toToken}],
    expiresIn
  );
  
  // transfer ownership to parentRequest owner
  await walletClient.changeOwnership({
    entityKey: entityKey,
    newOwner: parentOwner,
  });
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

async function fetchOffersParentFromUser(publicClient, parentRequestKey, userPublicKey) {
  const query = publicClient.buildQuery();
  const result = await query
  .where(eq('type', 'browser-wallet'))
  .where(eq('my_project', 'wins'))
  .where(eq('parent_request', parentRequestKey))
  .where(eq('$owner', userPublicKey))
  .withAttributes(true)
  .withPayload(true)
  .withMetadata(true)
  .fetch()
  return result.entities;
}
// called when entity is finalized, e.g. the trade is successful
// deletes all offers associated with the request, then deletes the request itself
// NOTE: offers should have ownership transferred to the request owner when created
async function finalizeRequest(walletClient, publicClient, requestKey) {
  const requestEntity = await publicClient.getEntity(requestKey);
  const userAddress = typeof walletClient.account === 'string' ? walletClient.account : walletClient.account.address;
  
  // verify the user is the owner of the request
  if (requestEntity.owner !== userAddress) {
    throw new Error("You're not the owner of this request");
  }
  
  const offersEntityList = await fetchOffersParent(publicClient, requestEntity.key);
  
  for (const offer of offersEntityList) {
    await walletClient.deleteEntity({ entityKey: offer.key }); // we can delete the offers because we transfered owneship when creating them, its secure because the transaction was already signed
  }
  
  await walletClient.deleteEntity({ entityKey: requestEntity.key });
}

export { createEntity, createBuyEntity, createSellEntity, fetchRequestsFromUserBuy, fetchRequestsFromUserSell, fetchOffersParentFromUser, fetchAllRequests, fetchRequestsFromToken, fetchRequestsFromTokenGTAmount, fetchRequestsFromTokenLTAmount, createOfferEntity, fetchOffersParent, fetchOffersParentToToken, finalizeRequest}