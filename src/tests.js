import {createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import {mendoza} from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString} from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt } from "@arkiv-network/sdk/query"
import { createBuyEntity, getEntityData, fetchUserEntities } from './main.js';

function testQuery() {
  // Empty as requested
}

async function testCreateBuyEntity() {
  // Check if MetaMask is installed
  if (!window.ethereum) {
    alert('Please install MetaMask!');
    return;
  }

  // Request access to the user's MetaMask accounts
  const [account] = await window.ethereum.request({ 
    method: 'eth_requestAccounts' 
  });

  // Connect to Arkiv using the Browser Wallet (MetaMask)
  const walletClient = createWalletClient({
    chain: mendoza,
    transport: custom(window.ethereum),
    account: account, 
  });

  // Public client for reads
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

    statusDiv.textContent = 'Creating buy entity...';

    // Create a buy entity
    const { entityKey, txHash } = await createBuyEntity(walletClient, 'ETH', 'USDC', '1.0');

    statusDiv.textContent = 'Fetching entity data...';
    const data = await getEntityData(publicClient, entityKey);

    statusDiv.textContent = 'Fetching user entities...';
    // Use the connected account address
    const userEntities = await fetchUserEntities(
      publicClient, 
      account, 
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
        <p><strong>Entities for ${account} (${userEntities.length}):</strong></p>
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

export {testQuery, testCreateBuyEntity};
