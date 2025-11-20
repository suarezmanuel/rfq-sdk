import { useAccount, useDisconnect } from 'wagmi'
import { User, Copy, LogOut, Wallet } from 'lucide-react'
import { useState } from 'react'

export default function Profile() {
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()
  const [copied, setCopied] = useState(false)

  const copyAddress = () => {
    if (address) {
      navigator.clipboard.writeText(address)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  return (
    <div className="min-h-screen bg-gray-950 text-white pb-20">
      <div className="max-w-4xl mx-auto px-4 py-8">
        <div className="flex items-center gap-3 mb-8">
          <User className="w-8 h-8 text-purple-500" />
          <h1 className="text-3xl font-bold">Profile</h1>
        </div>

        {isConnected && address ? (
          <div className="space-y-6">
            {/* Account Card */}
            <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
              <div className="flex items-center gap-4 mb-6">
                <div className="w-16 h-16 bg-purple-500/20 rounded-full flex items-center justify-center">
                  <Wallet className="w-8 h-8 text-purple-500" />
                </div>
                <div className="flex-1">
                  <p className="text-gray-400 text-sm mb-1">Wallet Address</p>
                  <div className="flex items-center gap-2">
                    <p className="font-mono text-sm">{address}</p>
                    <button
                      onClick={copyAddress}
                      className="p-1 hover:bg-gray-800 rounded transition-colors"
                      title="Copy address"
                    >
                      <Copy className="w-4 h-4 text-gray-400" />
                    </button>
                    {copied && (
                      <span className="text-xs text-green-500">Copied!</span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Account Details */}
            <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
              <h2 className="text-xl font-semibold mb-4">Account Details</h2>
              <div className="space-y-4">
                <div className="flex justify-between items-center py-3 border-b border-gray-800">
                  <span className="text-gray-400">Network</span>
                  <span className="font-semibold">Ethereum Mainnet</span>
                </div>
                <div className="flex justify-between items-center py-3 border-b border-gray-800">
                  <span className="text-gray-400">Account Type</span>
                  <span className="font-semibold">EOA</span>
                </div>
                <div className="flex justify-between items-center py-3">
                  <span className="text-gray-400">Status</span>
                  <span className="px-3 py-1 bg-green-500/20 text-green-500 rounded-full text-sm font-semibold">
                    Connected
                  </span>
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
              <h2 className="text-xl font-semibold mb-4">Actions</h2>
              <button
                onClick={() => disconnect()}
                className="w-full flex items-center justify-center gap-2 bg-red-500/20 hover:bg-red-500/30 text-red-500 font-semibold py-3 px-4 rounded-xl transition-colors"
              >
                <LogOut className="w-5 h-5" />
                Disconnect Wallet
              </button>
            </div>
          </div>
        ) : (
          <div className="bg-gray-900 rounded-2xl p-8 border border-gray-800 text-center">
            <User className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400 mb-4">
              Connect your wallet to view profile
            </p>
          </div>
        )}
      </div>
    </div>
  )
}

