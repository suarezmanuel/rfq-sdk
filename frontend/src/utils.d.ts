export type WalletClient = any

export declare function createBuyEntity(
  walletClient: WalletClient,
  fromAmount: string,
  fromToken: string,
  toToken: string,
  expiresIn?: any
): Promise<any>

export declare function createSellEntity(
  walletClient: WalletClient,
  fromAmount: string,
  fromToken: string,
  toToken: string,
  expiresIn?: any
): Promise<any>
