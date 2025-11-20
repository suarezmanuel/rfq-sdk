import { useState, useEffect } from 'react'
import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Wallet, X, ExternalLink } from 'lucide-react'

// Wallet icon mapping - you can replace these with actual wallet icons later
const getWalletIcon = (connectorName: string) => {
  const name = connectorName.toLowerCase()
  if (name.includes('metamask')) {
    return '🦊'
  } else if (name.includes('walletconnect')) {
    return '🔗'
  } else if (name.includes('injected')) {
    return '🌐'
  }
  return '💼'
}

const getWalletName = (connector: any) => {
  const name = connector.name?.toLowerCase() || ''
  if (name.includes('metamask')) {
    return 'MetaMask'
  } else if (name.includes('walletconnect')) {
    return 'WalletConnect'
  } else if (name.includes('injected') || name.includes('browser')) {
    return 'Browser Wallet'
  }
  return connector.name || 'Wallet'
}

export default function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { connectors, connect, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const [ isModalOpen, setIsModalOpen ] = useState(false)

  // Close modal when connected
  useEffect(() => {
    if (isConnected) {
      setIsModalOpen(false)
    }
  }, [ isConnected ])

  // Close modal on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsModalOpen(false)
      }
    }
    if (isModalOpen) {
      document.addEventListener('keydown', handleEscape)
      document.body.style.overflow = 'hidden'
    }
    return () => {
      document.removeEventListener('keydown', handleEscape)
      document.body.style.overflow = 'unset'
    }
  }, [ isModalOpen ])

  if (isConnected) {
    return (
      <div className="flex items-center gap-3">
        <div className="px-4 py-2 bg-gray-800 rounded-lg">
          <span className="text-sm font-mono">
            {address?.slice(0, 6)}...{address?.slice(-4)}
          </span>
        </div>
        <button
          onClick={() => disconnect()}
          className="px-4 py-2 bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors text-sm font-semibold"
        >
          Disconnect
        </button>
      </div>
    )
  }

  return (
    <>
      <button
        onClick={() => setIsModalOpen(true)}
        className="flex items-center gap-2 px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded-lg transition-colors text-sm font-semibold"
      >
        <Wallet className="w-4 h-4" />
        Connect Wallet
      </button>

      {/* Modal Overlay */}
      {isModalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          onClick={() => setIsModalOpen(false)}
        >
          {/* Backdrop */}
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />

          {/* Modal Content */}
          <div
            className="relative bg-gray-900 rounded-2xl border border-gray-800 w-full max-w-md p-6 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-white">Connect Wallet</h2>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
              >
                <X className="w-5 h-5 text-gray-400" />
              </button>
            </div>

            {/* Wallet List */}
            <div className="space-y-2">
              {connectors.map((connector) => {
                const walletName = getWalletName(connector)
                const walletIcon = getWalletIcon(connector.name || '')
                const isConnecting = isPending && connector.id === connectors.find(c => c.id === connector.id)?.id

                return (
                  <button
                    key={connector.uid}
                    onClick={() => {
                      connect({ connector })
                    }}
                    disabled={isConnecting}
                    className="w-full flex items-center gap-4 p-4 bg-gray-800 hover:bg-gray-700 rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed group"
                  >
                    <div className="w-12 h-12 bg-gray-700 group-hover:bg-gray-600 rounded-xl flex items-center justify-center text-2xl">
                      {walletIcon}
                    </div>
                    <div className="flex-1 text-left">
                      <p className="font-semibold text-white">{walletName}</p>
                      <p className="text-sm text-gray-400">
                        {isConnecting ? 'Connecting...' : 'Click to connect'}
                      </p>
                    </div>
                    <ExternalLink className="w-5 h-5 text-gray-400 group-hover:text-gray-300" />
                  </button>
                )
              })}
            </div>

            {/* Footer */}
            <p className="mt-6 text-xs text-center text-gray-500">
              By connecting, you agree to our Terms of Service and Privacy Policy
            </p>
          </div>
        </div>
      )}
    </>
  )
}

