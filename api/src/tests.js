import { createWalletClient, createPublicClient, http} from '@arkiv-network/sdk'
import { mendoza } from '@arkiv-network/sdk/chains'
import { stringToPayload, bytesToString, ExpirationTime } from '@arkiv-network/sdk/utils'
import { custom } from '@arkiv-network/sdk';
import { eq, gt } from "@arkiv-network/sdk/query"

import { createEntity, finalizeRequest, createBuyEntity, createSellEntity, fetchRequestsFromUserBuy, fetchRequestsFromUserSell, createOfferEntity, fetchOffersParent } from './utils.js';

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

    await createBuyEntity(walletClient, '1.0', 'ETH', 'USDC');
    const entity = (await fetchRequestsFromUserBuy(publicClient, walletClient.account)).at(-1);
    console.log("request entity:", entity);

    await createOfferEntity(walletClient, publicClient, entity.key, '3000.0', 'USDC');
    const offers = await fetchOffersParent(publicClient, entity.key);
    console.log("offer entity", offers);

    await finalizeRequest(walletClient, publicClient, entity.key);
    // returns [] when there are none.
    console.log(await fetchOffersParent(publicClient, entity.key));
    // returns Error when entity doesn't exist
    console.log(await publicClient.getEntity(entity.key));
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
  console.log(await fetchRequestsFromUserBuy(publicClient, walletClient.account));
  console.log(await fetchRequestsFromUserSell(publicClient, walletClient.account));
}
// test this in front
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

  await createBuyEntity(walletClient, '1.0', 'ETH', 'USDC');
  const entity = (await fetchRequestsFromUserBuy(publicClient, walletClient.account)).at(-1);
  console.log("request entity:", entity);

  let [offererAddress] = await window.ethereum.request({ method: 'eth_requestAccounts' });
  if (walletClient === offererAddress) {
    throw new Error("You didn't switch accounts! The buyer and offerer are the same.");
  }
  const offererClient = createWalletClient({
    chain: mendoza,
    transport: custom(window.ethereum),
    account: offererAddress,
  });

  await createOfferEntity(offererClient, publicClient, entity.key, '3000.0', 'USDC');
  const offers = await fetchOffersParent(publicClient, entity.key);
  console.log("offer entity", offers);
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

export {testQuery, testCreateBuyEntity, testCreateOfferAndFetchOffers};