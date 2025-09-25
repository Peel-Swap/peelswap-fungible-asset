# PEEL Token Client

Draft client to work with PEEL token

## Install

```bash
pnpm install
```

## Setup

Create `./client/.env`

```env
# Admin account private key
ADMIN_PRIVATE_KEY=ed25519-priv-0x...

# User account private key  
USER_PRIVATE_KEY=ed25519-priv-0x...

# Contract configuration
MODULE_ADDRESS=0xeda50089567df24c65db892ef0d680946feb739a01085ececec1009c9eb796af
MODULE_NAME=peelswap_fungible_asset
METADATA_ADDRESS=0xb8ec06c56ae7f89e8eb032b576f3c4b7688d166b137e7a92db5b20dc6a1e40c2
```

## Использование

### Run `index.ts`

```bash
pnpm start
```