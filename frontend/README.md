### smart contract api needed

1. make offer to request block
2. accept offer 
3. regret offer to request block
4. remove all offers made to request block

#### flow 

the main actions in the front end are:
1. create request
2. create offer to an existing request

A creates request to `buy 1000 ETH for DAI`, and the requests block is `1`.
B comes along and offers to A, to `sell 1000 ETH for 123123 DAI at block 1`.

when B creates the offer in frontend, B should send an `allow withdraw 1000 ETH for 123123 DAI from my account for block 1` to our smart contract at address `0x123`. (api 1) 

when A looks at the offers for his request to `buy 1000 ETH for DAI`,
if he accepts B's offer, A should send an `allow withdraw 123123 DAI from my account for 1000 ETH for block 1` to our smart contract at address `0x123`.

then the smart contract should swap the `ETH` and `DAI`.
the contract will fail if there is not enough balance for one of the parties.


if B made an offer and he regrets it, he should be able to cancel his `allow withdraw 1000 ETH for 123123 DAI from my account for block 1`, meaning revoke the allow and get a confirmation for it. (revoke success or failure).

if A and B traded, all the other allows should be removed for the block, index the allows by block id.

so the api should be like:

```js
function make_offer(fromAmount, fromToken, toAmount, toToken, rfqID) returns (bool);

function accept_offer(offerSenderAddr, toToken, rfqID) returns (bool);

function regret_offer(toToken, rfqID) returns (bool) public {
    // if transaction exists, remove it
    const offer = offers[rfqID][msg.sender][toToken]
    if (offer != "") {
        offers[rfqID][msg.sender][toToken] = "";
    }
    // ...
}

function _regret_offer(senderAddr, toToken, rfqID) returns (bool) private {
    // if transaction exists, remove it
    const offer = offers[rfqID][senderADdr][toToken]
    if (offer != "") {
        offers[rfqID][senderADdr][toToken] = "";
    }
    // ...
}

function remove_block_offers(rfqID) returns (bool) {
    for (offer in offers[rfqID]) {
        // we use the private implementation so we don't allow everyone to delete every offers
        _regret_offer(offer.sender, offer.toToken, rfqID);
    }
}
```