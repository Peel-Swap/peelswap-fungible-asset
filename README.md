# Peelswap Fungible Asset (PEEL)

This module implements the **PEEL** token for the Peelswap protocol on top of the Cedra Framework.  
The token is created as a managed `fungible_asset` with a public mint mechanism against CEDRA, plus admin functions for configuration.


## 📍 Deployment Info

| Network        | Module Address |
|----------------|--------------------------------------------------------------------------------|
| Cedra Devnet   | `0xeda50089567df24c65db892ef0d680946feb739a01085ececec1009c9eb796af::peelswap_fungible_asset` |
| Cedra Testnet  | _WIP_  |
| Cedra Mainnet  | _WIP_  |


# Setup

1. Clone repo
```sh
git clone git@github.com:Peel-Swap/peelswap-fungible-asset.git
```

2. Go to contract folder
```sh
cd contract
```

3. Compile
```sh
cedra move compile --named-addresses peelswap=dev
```

4. Test
```sh
cedra move test
```

5. Publish to devnet
```sh
cedra move publish --named-addresses peelswap=default
```
or to testnet
```sh
cedra move publish --named-addresses peelswap=test
```