import {createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import {mendoza} from '@arkiv-network/sdk/chains'
import { ExpirationTime, stringToPayload, bytesToString} from '@arkiv-network/sdk/utils'
import { privateKeyToAccount} from '@arkiv-network/sdk/accounts';
import { custom } from '@arkiv-network/sdk'; 

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
  return createEntity(walletClient, `sell ${fromAmount} ${fromToken} for an unknown amount of ${toToken}`, 'text/plain', [{ key: 'app_id', value: 'my-app-id' }, { key: 'tx-type', value: 'sell' }], expiresIn);
}

// fetch all entities owned by lookupAddress
// filter=[{key: 'app_id', value: 'my-app-id'}, {key: 'tx-type', value: 'buy'}]
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

// 2. Define a function to handle the connection (async wrapper)
async function connectAndWrite() {
  
  // Check if MetaMask is installed
  if (!window.ethereum) {
    alert('Please install MetaMask!');
    return;
  }

  // 3. Request access to the user's MetaMask accounts
  // This pops up the MetaMask window asking for permission
  const [account] = await window.ethereum.request({ 
    method: 'eth_requestAccounts' 
  });

  // 4. Connect to Arkiv using the Browser Wallet (MetaMask)
  const walletClient = createWalletClient({
    chain: mendoza,
    // 'custom' tells it to use the browser extension instead of a private key
    transport: custom(window.ethereum),
    account: account, 
  });

  // Public client can still use HTTP for faster reads, or custom(window.ethereum) too
  const publicClient = createPublicClient({
    chain: mendoza,
    transport: http('https://mendoza.hoodi.arkiv.network/rpc'),
  });

  const statusDiv = document.getElementById('status');
  const connectBtn = document.getElementById('connect-btn');
  
  try {
    statusDiv.textContent = 'Connecting to MetaMask...';
    connectBtn.disabled = true;
    
    console.log(`Connected as: ${account}`);
    console.log(Object.keys(publicClient)); 

    statusDiv.textContent = 'Creating entity...';

    // 5. Write the record (Triggers a MetaMask popup to sign/confirm)
    // const { entityKey, txHash } = await createBuyEntity(walletClient, 'ETH', 'USDC', '1.0');

    const { entityKey, txHash } = await walletClient.createEntity({
      payload: stringToPayload('Hello from MetaMask!'),
      contentType: 'text/plain',
      attributes: [
        { key: 'type', value: 'browser-wallet' }, 
        { key: 'tx_type', value: 'buy' }
      ],
      expiresIn: 120,
    });

    statusDiv.textContent = 'Fetching entity data...';
    const data = await getEntityData(publicClient, entityKey);

    statusDiv.textContent = 'Fetching user entities...';
    // Use the specific address (or use 'account' to fetch entities for the connected wallet)
    const lookupAddress = '0x702C101b2947A4d08D3aF49d3BF62D195b334cb1';
    const userEntities = await fetchUserEntities(
      publicClient, 
      lookupAddress, 
      10, 
      [{ key: 'type', value: 'browser-wallet' }]
    );

    console.log('Key:', entityKey);
    console.log('Data:', data);
    console.log('Tx:', txHash);
    console.log('User Entities:', userEntities);
    
    // Display entities list
    const entitiesList = userEntities.length > 0 
      ? userEntities.map((entity, idx) => 
          `<li style="margin: 8px 0; padding: 8px; background: #f5f5f5; border-radius: 4px;">
            <strong>Entity ${idx + 1}:</strong> <code style="font-size: 11px; word-break: break-all;">${entity.entityKey}</code>
          </li>`
        ).join('')
      : '<li>No entities found</li>';
    
    statusDiv.innerHTML = `
      <div style="text-align: center;">
        <p><strong>Success!</strong></p>
        <p>Entity Key: <code style="font-size: 12px; word-break: break-all;">${entityKey}</code></p>
        <p>Transaction: <code style="font-size: 12px; word-break: break-all;">${txHash}</code></p>
        <p>Data: ${data}</p>
        <hr style="margin: 20px 0;">
        <p><strong>Entities for ${lookupAddress} (${userEntities.length}):</strong></p>
        <ul style="list-style: none; padding: 0; max-width: 600px; margin: 0 auto; text-align: left;">
          ${entitiesList}
        </ul>
      </div>
    `;
    connectBtn.disabled = false;
  } catch (error) {
    console.error('Error:', error);
    statusDiv.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
    connectBtn.disabled = false;
  }
}

// Export functions for use in tests
export { createEntity, createBuyEntity, createSellEntity, fetchUserEntities, getEntityData };

// Export function to be called from HTML button
window.connectAndWrite = connectAndWrite;
window.testCreateBuyEntity = testCreateBuyEntity;