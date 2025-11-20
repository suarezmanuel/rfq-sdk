import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from './config/wagmi'
import Navigation from './components/Navigation'
import WalletConnect from './components/WalletConnect'
import Exchange from './components/Exchange'
import Profile from './components/Profile'
import './App.css'

const queryClient = new QueryClient()

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Router>
          <div className="min-h-screen bg-gray-950">
            {/* Header */}
            <header className="sticky top-0 z-50 bg-gray-900 border-b border-gray-800">
              <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
                <h1 className="text-xl font-bold text-white">Arkiv RFQ</h1>
                <WalletConnect />
              </div>
            </header>

            {/* Main Content */}
            <Routes>
              <Route path="/" element={<Exchange />} />
              <Route path="/exchange" element={<Exchange />} />
              <Route path="/profile" element={<Profile />} />
            </Routes>

            {/* Navigation */}
            <Navigation />
          </div>
        </Router>
      </QueryClientProvider>
    </WagmiProvider>
  )
}

export default App
