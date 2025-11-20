import { createPublicClient, http } from "@arkiv-network/sdk"
import { mendoza } from "@arkiv-network/sdk/chains"

const mendozaRpc = "https://mendoza.hoodi.arkiv.network/rpc"

export const publicClient = createPublicClient({
  chain: mendoza,
  transport: http(mendozaRpc)
})
