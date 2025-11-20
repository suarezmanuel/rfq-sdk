import { testQuery, testCreateBuyEntity, testCreateOfferAndFetchOffers } from './tests.js';

localStorage.debug = 'arkiv:*'
// Function to be called from HTML button
// window.connectAndWrite = testCreateBuyEntity;
window.connectAndWrite = testQuery;