import { useQuery } from "@tanstack/react-query"
import * as sdk from "../../../api/src/utils"
import { publicClient } from "../core/client"
import type { Offer } from "../types/offer"

export function useOffers() {
  return useQuery({
    queryKey: ["offers"],
    queryFn: async () => {
      const offers: Offer[] = await sdk.fetchAllRequests(publicClient)

      console.log({ offers })

      // try {
      //   console.log({
      //     order: JSON.(JSON.stringify(offers[17], replacer)),
      //     s: offers[17]
      //   })
      // } catch (error) {
      //   console.log({ error })
      // }

      const requiredAttributes = [
        "app_id",
        "from_amount",
        "from_token",
        "my_project",
        "to_token",
        "tx_type",
        "type"
      ]

      const filtered = offers.filter(offer => {
        const attrKeys = new Set(offer.attributes.map(a => a.key))
        return requiredAttributes.every(req => attrKeys.has(req))
      })

      console.log({ filtered, offers })
      return filtered
    }
  })
}

// // handles bigint
// const replacer = (key: string, value: any) => {
//   if (typeof value === "bigint") {
//     return value.toString()
//   }
//   return value
// }
