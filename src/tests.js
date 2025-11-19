import { createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import { mendoza } from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString, ExpirationTime } from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt } from "@arkiv-network/sdk/query"

import { createEntity, createBuyEntity, createSellEntity, fetchUserEntities, getEntityData } from './utils.js';

async function testQuery() {
    await testCreateBuyEntity();
    // await testCreateSellEntity();
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

  console.log(walletClient);

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

    console.log('Key:', entityKey);
    console.log('Data:', data);
    console.log('Tx:', txHash);
    
    statusDiv.innerHTML = `
      <div style="text-align: center;">
        <p><strong>Success!</strong></p>
      </div>
    `;
    connectBtn.disabled = false;
  } catch (error) {
    console.error('Error:', error);
    statusDiv.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
    connectBtn.disabled = false;
  }
}

async function testCreateSellEntity() {
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
      const { entityKey, txHash } = await createSellEntity(walletClient, 'ETH', 'USDC', '1.0');
  
      statusDiv.textContent = 'Fetching entity data...';
      const data = await getEntityData(publicClient, entityKey);
  
      console.log('Key:', entityKey);
      console.log('Data:', data);
      console.log('Tx:', txHash);
      
      statusDiv.innerHTML = `
        <div style="text-align: center;">
          <p><strong>Success!</strong></p>
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