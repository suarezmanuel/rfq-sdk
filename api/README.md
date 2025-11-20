### prequisites
have a working metamask wallet that has the 'mendoza' chain activated and has funds from the faucet
all that can be done at https://mendoza.hoodi.arkiv.network/

The sdk has two main functionalities: 
1. read existing request / offer data. 
2. write new buy/sell requests / write new offers.

and is fitted to host requests, offers:
1. P2P current requests site, personal requests history
2. P2P offers for each request, P2P offers for each personal request

### how to read P2P requests feed 

```js
// fetches all current live requests
fetchAllRequests(publicClient);
// filter by token symbol
fetchAllRequestsFromToken(publicClient, fromToken);
// filter by token symbol and amount
fetchAllrequestsFromTokenGTAmount(publicClient, fromToken, amount);
fetchAllrequestsFromTokenLTAmount(publicClient, fromToken, amount);
```

these functions return a list of entities, where each entity has the fields:
`fromToken, fromAmount, tx_type, toToken, txHash, timestamp, payload`

```json
example 'request' entity object
{
    "key": "0x0b4b7282ca7d34f82ff892ce69466089a932f5284978be939364a61433ea0425",
    "payload": {
        "0": 115,
        "1": 101,
        "2": 108,
        "3": 108,
        "4": 32,
        "5": 49,
        "6": 46,
        "7": 48,
        "8": 32,
        "9": 69,
        "10": 84,
        "11": 72,
        "12": 32,
        "13": 102,
        "14": 111,
        "15": 114,
        "16": 32,
        "17": 97,
        "18": 110,
        "19": 32,
        "20": 117,
        "21": 110,
        "22": 107,
        "23": 110,
        "24": 111,
        "25": 119,
        "26": 110,
        "27": 32,
        "28": 97,
        "29": 109,
        "30": 111,
        "31": 117,
        "32": 110,
        "33": 116,
        "34": 32,
        "35": 111,
        "36": 102,
        "37": 32,
        "38": 85,
        "39": 83,
        "40": 68,
        "41": 67
    },
    "attributes": [
        {
            "key": "app_id",
            "value": "my-app-id"
        },
        {
            "key": "from_amount",
            "value": "1.0"
        },
        {
            "key": "from_token",
            "value": "ETH"
        },
        {
            "key": "my_project",
            "value": "wins"
        },
        {
            "key": "to_token",
            "value": "USDC"
        },
        {
            "key": "tx_type",
            "value": "sell"
        },
        {
            "key": "type",
            "value": "browser-wallet"
        }
    ]
}
```

when the list of entities is given, we can get each fields by doing

```js
entities.forEach((entity) => {
    
    console.log(entity.key) // txHash
    console.log(entity.owner) // owner addr

    console.log(entity.attributes.find(
        attr => attr.key === 'tx_type')?.value
    ) // prints 'buy', 'sell', 'offer'

    console.log(entity.attributes.find(
        attr => attr.key === 'to_token')?.value
    ) // prints the symbol 'ETH', 'DAI'

    console.log(entity.attributes.find(
        attr => attr.key === 'from_token')?.value
    ) // prints the symbol 'ETH', 'DAI'

    console.log(entity.attributes.find(
        attr => attr.key === 'from_amount')?.value
    ) // prints a decimal number 100.32, 1123214.0, 1.0
    
    console.log(bytesToString(entity.payload)) // print desc

    console.log()

});
```

### how to read P2P offers

you first need a request's key, because the offers are indexed by request.
when you are to display the entities list that represents the requests feed,
when the user clicks a request, you retrieve the key by doing `entitiesList[index].key`
then to get the offers of that request, we use the API

```js
// filter transactions by offer, parentKey
fetchOffersParent(publicClient, parentRequestKey);
// filter trasanctions also by toToken
fetchOffersParentToToken(publicClient, parentRequestKey, toToken);
```

```js
// const parentKey = await createBuyEntity(walletClient, 'ETH', 'USDC', '1.0');
const parentKey =  entitiesList[index].key
await createOfferEntity(walletClient, parentKey, 'USDC', '3000.0');
const offers = await fetchOffersParent(publicClient, parentKey);
console.log(offers);
```

### how to read own requests feed

with the API 

```js
// fetch own requests filtered by tx_type=buy
function fetchRequestsFromUserBuy(publicClient, userAddress);
// fetch own requests filtered by tx_type=sell
function fetchRequestsFromUserSell(publicClient, userAddress);
```

we can technically get the requests of any user (can be implemented as a page when you click on a users' addr, might be good). 
the current idea is to use it to fetch the own user's request, by doing:

```js
console.log(await fetchRequestsFromUserBuy(publicClient, userAddress));
console.log(await fetchRequestsFromUserSell(publicClient, userAddress));
```

where 

```js
const publicClient = createPublicClient({
      chain: mendoza,
      transport: http('https://mendoza.hoodi.arkiv.network/rpc'),
});

const userAddress = typeof walletClient.account === 'string' ?
      walletClient.account 
        : 
      walletClient.account.address;
```


### how to read own requests' offers

same as the `to read P2P offers`.

### how to write a request

```js
await createBuyEntity(walletClient, '1.0', 'ETH', 'USDC');
await createSellEntity(walletClient, '3500.0', 'USDC', 'ETH');
```

where

```js
const [account] = await window.ethereum.request({ 
    method: 'eth_requestAccounts' 
});

// Connect to Arkiv using the Browser Wallet (MetaMask)
const walletClient = createWalletClient({
    chain: mendoza,
    transport: custom(window.ethereum),
    account: account, 
});
```

we should see it on the own requests feed, and should appear in the P2P.

### how to write an offer to a request (that is not your own)

```js
const newestRequest = (await createBuyEntity(walletClient, 'ETH', 'USDC', '1.0')).at(-1);
const parentKey = newestRequest.key;
await createOfferEntity(walletClient, parentKey, 'USDC', '3000.0');
```

we should now see it when checking the same request later

### ideas to maybe implement

- add binance as an offer that is always available to all requests

- we can technically get the requests of any user (can be implemented as a page when you click on a users' addr, might be good). 

- if we have a page of own requests, maybe we can also make a page of own offers made, with
`function fetchOffersParentFromUser(publicClient, parentRequestKey, userPublicKey)`