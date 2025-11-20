import { useState } from 'react'
import { useAccount } from 'wagmi'
import { ArrowUpDown, User, X, Copy, Trash2 } from 'lucide-react'

// Token icon component - placeholder for actual token images
function TokenIcon({ token }: { token: string }) {
  const getTokenColor = (token: string) => {
    const colors: Record<string, string> = {
      ETH: 'bg-blue-500',
      BTC: 'bg-orange-500',
      USDC: 'bg-blue-400',
    }
    return colors[ token ] || 'bg-purple-500'
  }

  return (
    <div
      className={`w-12 h-12 ${getTokenColor(token)} rounded-full flex items-center justify-center text-white font-bold text-sm`}
    >
      {token.slice(0, 2)}
    </div>
  )
}

// Mock offers data
const mockOffers = [
  {
    id: 1,
    user: '0x1234...5678',
    token: 'ETH',
    tokenAddress: '0x0000000000000000000000000000000000000001',
    amount: '1.5',
    price: '$1,200',
    usdAmount: '$1,800',
    type: 'Buy',
    createdAt: '2025-11-19 14:32',
  },
  {
    id: 2,
    user: '0xabcd...efgh',
    token: 'USDC',
    tokenAddress: '0x0000000000000000000000000000000000000002',
    amount: '1000',
    price: '$1.00',
    usdAmount: '$1,000',
    type: 'Sell',
    createdAt: '2025-11-18 10:15',
  },
  {
    id: 3,
    user: '0x9876...5432',
    token: 'BTC',
    tokenAddress: '0x0000000000000000000000000000000000000003',
    amount: '0.1',
    price: '$45,000',
    usdAmount: '$4,500',
    type: 'Buy',
    createdAt: '2025-11-19 09:05',
  },
  {
    id: 4,
    user: '0xfedc...ba98',
    token: 'ETH',
    tokenAddress: '0x0000000000000000000000000000000000000001',
    amount: '2.0',
    price: '$1,250',
    usdAmount: '$2,500',
    type: 'Sell',
    createdAt: '2025-11-17 16:45',
  },
  {
    id: 5,
    user: '0x1111...2222',
    token: 'USDC',
    tokenAddress: '0x0000000000000000000000000000000000000002',
    amount: '500',
    price: '$1.00',
    usdAmount: '$500',
    type: 'Buy',
    createdAt: '2025-11-16 12:20',
  },
  {
    id: 6,
    user: '0x3333...4444',
    token: 'BTC',
    tokenAddress: '0x0000000000000000000000000000000000000003',
    amount: '0.05',
    price: '$45,000',
    usdAmount: '$2,250',
    type: 'Sell',
    createdAt: '2025-11-15 08:55',
  },
]

const mockRepliesByOfferId: Record<number, {
  id: number
  from: string
  amount: string
  token: string
  price: string
  usdValue: string
}[]> = {
  1: [
    {
      id: 1,
      from: '0xaaaa...bbbb',
      amount: '5',
      token: 'ETH',
      price: '1 ETH = 1200 DAI',
      usdValue: '$6,000',
    },
    {
      id: 2,
      from: '0xcccc...dddd',
      amount: '4.5',
      token: 'ETH',
      price: '1 ETH = 1150 DAI',
      usdValue: '$5,175',
    },
  ],
  4: [
    {
      id: 3,
      from: '0xeeee...ffff',
      amount: '2',
      token: 'ETH',
      price: '1 ETH = 1250 USDC',
      usdValue: '$2,500',
    },
  ],
}

export default function Exchange() {
  const { isConnected } = useAccount()
  const [ activeTab, setActiveTab ] = useState<'MyOffers' | 'P2PMarket'>('MyOffers')
  const [ selectedOffer, setSelectedOffer ] = useState<(typeof mockOffers)[ number ] | null>(null)
  const [ tokenFilter, setTokenFilter ] = useState<string>('All')
  const [ sortKey, setSortKey ] = useState<'amount' | 'usd' | 'price'>('usd')
  const [ sortDirection, setSortDirection ] = useState<'asc' | 'desc'>('desc')
  const [ offers, setOffers ] = useState<typeof mockOffers>(mockOffers)

  const currentUser = '0x1234...5678'

  const myOffers = offers.filter((offer) => offer.user === currentUser)
  const p2pOffers = offers.filter((offer) => offer.user !== currentUser)

  const displayedOffersBase = activeTab === 'MyOffers' ? myOffers : p2pOffers

  const availableTokens = Array.from(new Set(offers.map((offer) => offer.token)))

  const parseCurrency = (value: string) => {
    return parseFloat(value.replace(/[^0-9.]/g, ''))
  }

  const parseNumber = (value: string) => {
    return parseFloat(value.replace(/,/g, ''))
  }

  const filteredOffers = displayedOffersBase.filter((offer) => {
    if (tokenFilter !== 'All' && offer.token !== tokenFilter) {
      return false
    }
    return true
  })

  const sortedOffers = [ ...filteredOffers ].sort((a, b) => {
    let aValue = 0
    let bValue = 0

    if (sortKey === 'amount') {
      aValue = parseNumber(a.amount)
      bValue = parseNumber(b.amount)
    } else if (sortKey === 'usd') {
      aValue = parseCurrency(a.usdAmount)
      bValue = parseCurrency(b.usdAmount)
    } else if (sortKey === 'price') {
      aValue = parseCurrency(a.price)
      bValue = parseCurrency(b.price)
    }

    if (Number.isNaN(aValue) || Number.isNaN(bValue)) {
      return 0
    }

    if (aValue === bValue) {
      return 0
    }

    const direction = sortDirection === 'asc' ? 1 : -1
    return aValue > bValue ? direction : -direction
  })

  const handleCopy = async (value: string) => {
    try {
      await navigator.clipboard.writeText(value)
    } catch {
      // ignore copy errors for now
    }
  }

  return (
    <div className="min-h-screen bg-gray-950 text-white pb-20">
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="flex items-center gap-3 mb-8">
          <ArrowUpDown className="w-8 h-8 text-purple-500" />
          <h1 className="text-3xl font-bold">Exchange</h1>
        </div>

        {isConnected ? (
          <>
            {/* Tabs */}
            <div className="flex gap-2 mb-6 bg-gray-900 p-1 rounded-xl border border-gray-800">
              <button
                onClick={() => setActiveTab('MyOffers')}
                className={`flex-1 py-3 px-4 rounded-lg font-semibold transition-colors ${activeTab === 'MyOffers'
                  ? 'bg-purple-500/20 text-purple-500'
                  : 'text-gray-400 hover:text-gray-300'
                  }`}
              >
                My offers ({myOffers.length})
              </button>
              <button
                onClick={() => setActiveTab('P2PMarket')}
                className={`flex-1 py-3 px-4 rounded-lg font-semibold transition-colors ${activeTab === 'P2PMarket'
                  ? 'bg-blue-500/20 text-blue-400'
                  : 'text-gray-400 hover:text-gray-300'
                  }`}
              >
                P2P market ({p2pOffers.length})
              </button>
            </div>

            {/* Offers List */}
            <div className="flex items-center justify-between gap-4 mb-4 flex-wrap">
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-400">Token</span>
                <select
                  value={tokenFilter}
                  onChange={(event) => setTokenFilter(event.target.value)}
                  className="bg-gray-900 border border-gray-800 rounded-lg px-3 py-1.5 text-sm text-gray-100 focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="All">All</option>
                  {availableTokens.map((token) => (
                    <option key={token} value={token}>
                      {token}
                    </option>
                  ))}
                </select>
              </div>
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-400">Sort by</span>
                <select
                  value={sortKey}
                  onChange={(event) => setSortKey(event.target.value as 'amount' | 'usd' | 'price')}
                  className="bg-gray-900 border border-gray-800 rounded-lg px-3 py-1.5 text-sm text-gray-100 focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="usd">USD value</option>
                  <option value="amount">Amount</option>
                  <option value="price">Price</option>
                </select>
                <button
                  type="button"
                  onClick={() => setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')}
                  className="p-1.5 rounded-lg bg-gray-900 border border-gray-800 hover:bg-gray-800 text-gray-300 transition-colors flex items-center justify-center"
                >
                  <ArrowUpDown className={`w-4 h-4 ${sortDirection === 'asc' ? 'rotate-180' : ''}`} />
                </button>
              </div>
            </div>
            <div className="space-y-4">
              {sortedOffers.length > 0 ? (
                sortedOffers.map((offer) => (
                  <div
                    key={offer.id}
                    className="bg-gray-900 rounded-2xl p-6 border border-gray-800 hover:border-purple-500/50 transition-colors"
                  >
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex items-center gap-3">
                        <TokenIcon token={offer.token} />
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="text-lg font-bold">
                              {offer.amount} {offer.token} | {offer.usdAmount}
                            </span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-gray-400">
                            <User className="w-4 h-4" />
                            <span>{offer.user}</span>
                          </div>
                          {activeTab === 'MyOffers' && (
                            <div className="mt-1 text-xs text-gray-500">
                              Created at {offer.createdAt}
                            </div>
                          )}
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-sm text-gray-400">Price</p>
                        <p className="text-lg font-semibold">{offer.price}</p>
                      </div>
                    </div>

                    <div className="flex gap-3">
                      {activeTab === 'MyOffers' ? (
                        <>
                          <button
                            className="flex-1 bg-gray-800 hover:bg-gray-700 text-white font-semibold py-3 px-4 rounded-xl transition-colors flex items-center justify-center gap-2"
                            onClick={() => setSelectedOffer(offer)}
                          >
                            View Details
                          </button>
                          <button
                            className="w-12 bg-red-500/10 hover:bg-red-500/20 text-red-400 hover:text-red-300 font-semibold py-3 rounded-xl transition-colors flex items-center justify-center"
                            onClick={() => setOffers((prev) => prev.filter((item) => item.id !== offer.id))}
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </>
                      ) : (
                        <>
                          <button className="flex-1 bg-purple-600 hover:bg-purple-700 text-white font-semibold py-3 px-4 rounded-xl transition-colors">
                            Accept Offer
                          </button>
                          <button
                            className="flex-1 bg-gray-800 hover:bg-gray-700 text-white font-semibold py-3 px-4 rounded-xl transition-colors"
                            onClick={() => setSelectedOffer(offer)}
                          >
                            View Details
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                ))
              ) : (
                <div className="bg-gray-900 rounded-2xl p-8 border border-gray-800 text-center">
                  <p className="text-gray-400">
                    No offers available in this view
                  </p>
                </div>
              )}
            </div>
            <div className="mt-8">
              <button className="w-full py-4 rounded-2xl bg-purple-600 hover:bg-purple-700 text-white font-semibold text-lg transition-colors">
                Add offer +
              </button>
            </div>
            {selectedOffer && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
                <div className="w-full max-w-md bg-gray-900 border border-gray-800 rounded-2xl p-6 shadow-xl">
                  <div className="flex items-center justify-between mb-4">
                    <h2 className="text-xl font-semibold">Offer details</h2>
                    <button
                      className="p-1 rounded-full hover:bg-gray-800 text-gray-400 hover:text-gray-200 transition-colors"
                      onClick={() => setSelectedOffer(null)}
                    >
                      <X className="w-5 h-5" />
                    </button>
                  </div>
                  <div className="space-y-4 text-sm">
                    <div>
                      <p className="text-gray-400 mb-1">Wallet address</p>
                      <div className="flex items-center gap-2">
                        <span className="font-mono break-all text-xs flex-1">{selectedOffer.user}</span>
                        <button
                          className="flex items-center gap-1 px-2 py-1 text-xs bg-gray-800 hover:bg-gray-700 rounded-md text-gray-200 transition-colors"
                          onClick={() => handleCopy(selectedOffer.user)}
                        >
                          <Copy className="w-3 h-3" />
                          Copy
                        </button>
                      </div>
                    </div>
                    <div>
                      <p className="text-gray-400 mb-1">Token</p>
                      <p className="font-medium">{selectedOffer.token}</p>
                    </div>
                    <div>
                      <p className="text-gray-400 mb-1">Token address</p>
                      <p className="font-mono break-all text-xs">{selectedOffer.tokenAddress}</p>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-gray-400 mb-1">Amount</p>
                        <p className="font-medium">
                          {selectedOffer.amount} {selectedOffer.token}
                        </p>
                      </div>
                      <div>
                        <p className="text-gray-400 mb-1">USD value</p>
                        <p className="font-medium">{selectedOffer.usdAmount}</p>
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-gray-400 mb-1">Price</p>
                        <p className="font-medium">{selectedOffer.price}</p>
                      </div>
                      <div>
                        <p className="text-gray-400 mb-1">Side</p>
                        <p className="font-medium">{selectedOffer.type}</p>
                      </div>
                    </div>
                    {selectedOffer.user === currentUser && (
                      <>
                        <div>
                          <p className="text-gray-400 mb-2">Replies to this offer</p>
                          <div className="space-y-2 max-h-40 overflow-y-auto">
                            {(mockRepliesByOfferId[ selectedOffer.id ] || []).map((reply) => (
                              <div
                                key={reply.id}
                                className="flex items-center justify-between px-3 py-2 rounded-lg bg-gray-800/80 border border-gray-700"
                              >
                                <div>
                                  <p className="text-xs text-gray-400">From {reply.from}</p>
                                  <p className="text-sm font-medium">
                                    {reply.amount} {reply.token}
                                  </p>
                                </div>
                                <div className="text-right text-xs">
                                  <p className="text-gray-400">Quote</p>
                                  <p className="font-semibold">{reply.price}</p>
                                  <p className="text-gray-400 mt-1">{reply.usdValue}</p>
                                </div>
                              </div>
                            ))}
                            {(!mockRepliesByOfferId[ selectedOffer.id ] || mockRepliesByOfferId[ selectedOffer.id ].length === 0) && (
                              <p className="text-xs text-gray-500">No replies yet for this offer.</p>
                            )}
                          </div>
                        </div>
                        <div className="mt-4 p-3 rounded-xl bg-yellow-500/10 border border-yellow-500/40 text-xs">
                          <div className="flex items-center justify-between mb-1">
                            <p className="font-semibold text-yellow-400">Binance comparison (mock)</p>
                            <p className="text-gray-400">Example price</p>
                          </div>
                          <p className="text-sm">
                            If you executed this trade on Binance, you would get approximately
                            <span className="font-semibold text-yellow-300"> 1 ETH ≈ $1,230</span>.
                          </p>
                        </div>
                      </>
                    )}
                  </div>
                  <button
                    className="mt-6 w-full py-3 rounded-xl bg-purple-600 hover:bg-purple-700 font-semibold text-white transition-colors"
                    onClick={() => setSelectedOffer(null)}
                  >
                    Close
                  </button>
                </div>
              </div>
            )}
          </>
        ) : (
          <div className="bg-gray-900 rounded-2xl p-8 border border-gray-800 text-center">
            <ArrowUpDown className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 mb-4">
              Connect your wallet to view offers
            </p>
          </div>
        )}
      </div>
    </div>
  )
}

