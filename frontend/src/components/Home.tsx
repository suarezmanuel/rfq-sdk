import { useAccount, useBalance } from 'wagmi'
import { Wallet, TrendingUp, Clock } from 'lucide-react'

export default function Home() {
  const { address, isConnected } = useAccount()
  const { data: balance } = useBalance({
    address: address,
  })

  // Mock recent trades data
  const recentTrades = [
    {
      id: 1,
      type: 'Buy',
      token: 'ETH',
      amount: '0.5',
      price: '$1,200',
      time: '2 hours ago',
    },
    {
      id: 2,
      type: 'Sell',
      token: 'USDC',
      amount: '500',
      price: '$1.00',
      time: '5 hours ago',
    },
    {
      id: 3,
      type: 'Buy',
      token: 'BTC',
      amount: '0.01',
      price: '$45,000',
      time: '1 day ago',
    },
  ]

  return (
    <div className="min-h-screen bg-gray-950 text-white pb-20">
      <div className="max-w-4xl mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">Wallet</h1>

        {isConnected ? (
          <>
            {/* Balance Card */}
            <div className="bg-gray-900 rounded-2xl p-6 mb-6 border border-gray-800">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-purple-500/20 rounded-full flex items-center justify-center">
                    <Wallet className="w-6 h-6 text-purple-500" />
                  </div>
                  <div>
                    <p className="text-gray-400 text-sm">Total Balance</p>
                    <p className="text-2xl font-bold">
                      {balance?.formatted} {balance?.symbol}
                    </p>
                  </div>
                </div>
              </div>
              <div className="flex gap-4">
                <button className="flex-1 bg-purple-600 hover:bg-purple-700 text-white font-semibold py-3 px-4 rounded-xl transition-colors">
                  Send
                </button>
                <button className="flex-1 bg-gray-800 hover:bg-gray-700 text-white font-semibold py-3 px-4 rounded-xl transition-colors">
                  Receive
                </button>
              </div>
            </div>

            {/* Recent Trades */}
            <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
              <div className="flex items-center gap-2 mb-4">
                <Clock className="w-5 h-5 text-gray-400" />
                <h2 className="text-xl font-semibold">Recent Trades</h2>
              </div>
              <div className="space-y-3">
                {recentTrades.map((trade) => (
                  <div
                    key={trade.id}
                    className="flex items-center justify-between p-4 bg-gray-800/50 rounded-xl hover:bg-gray-800 transition-colors"
                  >
                    <div className="flex items-center gap-3">
                      <div
                        className={`w-10 h-10 rounded-full flex items-center justify-center ${
                          trade.type === 'Buy'
                            ? 'bg-green-500/20'
                            : 'bg-red-500/20'
                        }`}
                      >
                        <TrendingUp
                          className={`w-5 h-5 ${
                            trade.type === 'Buy'
                              ? 'text-green-500'
                              : 'text-red-500'
                          }`}
                        />
                      </div>
                      <div>
                        <p className="font-semibold">
                          {trade.type} {trade.token}
                        </p>
                        <p className="text-sm text-gray-400">{trade.time}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold">
                        {trade.amount} {trade.token}
                      </p>
                      <p className="text-sm text-gray-400">{trade.price}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </>
        ) : (
          <div className="bg-gray-900 rounded-2xl p-8 border border-gray-800 text-center">
            <Wallet className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 mb-4">Connect your wallet to get started</p>
          </div>
        )}
      </div>
    </div>
  )
}

