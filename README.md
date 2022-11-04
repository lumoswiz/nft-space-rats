# Space Rats

**An NFT project inspired by a [BowTiedPickle](https://twitter.com/BowTiedPickle/status/1586082088746639361) post.**

## Setup

- Install [Foundry](https://github.com/foundry-rs/foundry).

## Exercise Description

Problem specification from project brief:

- A genesis drop of 2000 Space Rat PFP NFts with 1000 mintable by whitelisted addresses and public addresses, respectively.
- Rats can be sent to work in asteroid mines to earn Iridium tokens and Geodes.
- Geodes can be cracked open to earn rewards, such as: whitelist spots, more Iridium tokens or spaceship keys.
- Spaceship art design to be finalised, but anticipate that spaceship keys will be used to unlock additional functional, such as: reward mining speed.

## Todo

- Modify Bagholder.sol contract to:
  - [ ] Handle rewards (ERC-20, ERC-721, ERC-1155); ERC1155Holder.sol
  - [ ] Functionality to transfer ERC-1155 tokens out of staking contract.
- [ ] Implement Geodes contract (including MINTER_ROLE).
- [x] Implement Iridium token contract (including MINTER_ROLE).

## Acknowledgements

- [Bagholder](https://github.com/ZeframLou/bagholder) from ZeframLou.
