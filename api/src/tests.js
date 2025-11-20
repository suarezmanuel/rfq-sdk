import { createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import { mendoza } from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString, ExpirationTime } from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt } from "@arkiv-network/sdk/query"

import { createEntity, createBuyEntity, createSellEntity, fetchRequestsFromUserBuy, fetchRequestsFromUserSell, createOfferEntity, fetchOffersParent } from './utils.js';

async function testQuery() {

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

    console.log(walletClient, typeof(walletClient));

    // Public client for reads
    const publicClient = createPublicClient({
        chain: mendoza,
        transport: http('https://mendoza.hoodi.arkiv.network/rpc'),
    });

    const statusDiv = document.getElementById('status');
    const connectBtn = document.getElementById('connect-btn');

    statusDiv.textContent = 'Connecting to MetaMask...';
    connectBtn.disabled = true;
    
    console.log(`Connected as: ${account}`);

    console.log(publicClient, walletClient.account)
    const userAddress = typeof walletClient.account === 'string' ? walletClient.account : walletClient.account.address;
    console.log(await fetchRequestsFromUserBuy(publicClient, userAddress));
    console.log(await fetchRequestsFromUserSell(publicClient, userAddress));
}

async function testFetchUserBuyAndSellRequests() {

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

  console.log(walletClient, typeof(walletClient));

  // Public client for reads
  const publicClient = createPublicClient({
      chain: mendoza,
      transport: http('https://mendoza.hoodi.arkiv.network/rpc'),
  });

  const statusDiv = document.getElementById('status');
  const connectBtn = document.getElementById('connect-btn');

  statusDiv.textContent = 'Connecting to MetaMask...';
  connectBtn.disabled = true;
  
  console.log(`Connected as: ${account}`);

  console.log(publicClient, walletClient.account)
  const userAddress = typeof walletClient.account === 'string' ? walletClient.account : walletClient.account.address;
  console.log(await fetchRequestsFromUserBuy(publicClient, userAddress));
  console.log(await fetchRequestsFromUserSell(publicClient, userAddress));
}

async function testCreateOfferAndFetchOffers() {

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

  statusDiv.textContent = 'Connecting to MetaMask...';
  connectBtn.disabled = true;
  
  console.log(`Connected as: ${account}`);
  console.log(Object.keys(publicClient)); 

  const { entityKey: parentKey } = await createBuyEntity(walletClient, '1.0', 'ETH', 'USDC');
  await createOfferEntity(walletClient, publicClient, parentKey, '3000.0', 'USDC');
  const offers = await fetchOffersParent(publicClient, parentKey);
  console.log(offers);
}

async function testCreateBuyEntity(publicClient, walletClient, statusDiv, connectBtn) {
  
  try {

    statusDiv.textContent = 'Creating buy entity...';

    // Create a buy entity
    const { entityKey, txHash } = await createBuyEntity(walletClient, '1.0', 'ETH', 'USDC');

    statusDiv.textContent = 'Fetching entity data...';
    const data = await publicClient.getEntity(entityKey);

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

async function testCreateSellEntity(publicClient, walletClient, statusDiv, connectBtn) {
    
    try {
      
      statusDiv.textContent = 'Creating sell entity...';
  
      // Create a buy entity
      const { entityKey, txHash } = await createSellEntity(walletClient,  '1.0', 'ETH', 'USDC');
  
      statusDiv.textContent = 'Fetching entity data...';
      const data = await publicClient.getEntity(entityKey);
  
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