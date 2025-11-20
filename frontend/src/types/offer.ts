export interface Offer {
  key: string
  contentType: string
  owner: string
  expiresAtBlock: string
  createdAtBlock: string
  lastModifiedAtBlock: string
  transactionIndexInBlock: string
  operationIndexInTransaction: string
  payload: { [key: string]: number }
  attributes: Attribute[]
}

export interface Attribute {
  key: string
  value: string
}
