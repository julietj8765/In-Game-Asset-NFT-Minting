# 🎮 In-Game Asset NFT Minting

> 🚀 Dynamic NFT minting system that creates unique game assets based on player achievements and game events

## 🌟 Overview

This smart contract enables dynamic minting of NFT game assets triggered by in-game events and achievements. Players earn unique collectible assets by reaching score thresholds and completing specific game challenges.

## ✨ Features

- 🎯 **Event-Driven Minting**: Assets are automatically minted when players achieve specific milestones
- 🏆 **Achievement System**: Track player statistics including total score, games played, and achievements
- 🎲 **Multiple Asset Types**: Weapons, armor, accessories, gems, and tools with varying rarities
- 📊 **Player Stats Tracking**: Comprehensive tracking of player progress and activity
- 🔄 **Batch Minting**: Claim all eligible assets in a single transaction
- 👑 **Admin Controls**: Game state management and special asset minting capabilities

## 🎮 Game Events & Assets

| Event | Required Score | Asset | Type | Rarity |
|-------|----------------|-------|------|--------|
| 🗡️ First Kill | 10 | Rookie Sword | Weapon | Common |
| 💰 Treasure Hunter | 30 | Golden Compass | Tool | Uncommon |
| 👹 Boss Defeat | 50 | Victory Crown | Accessory | Rare |
| ⚡ Speed Run | 75 | Lightning Boots | Armor | Rare |
| 💯 Perfect Score | 100 | Flawless Crystal | Gem | Epic |
| 🐉 Dragon Slayer | 200 | Dragon Scale Shield | Armor | Legendary |

## 🛠️ Usage

### Player Functions

#### Register as a Player
```clarity
(contract-call? .in-game-asset-nft-minting register-player)
```

#### Update Your Score After a Game
```clarity
(contract-call? .in-game-asset-nft-minting update-player-score u25)
```

#### Mint Asset from Specific Event
```clarity
(contract-call? .in-game-asset-nft-minting mint-asset-from-event "first-kill")
```

#### Batch Mint All Eligible Assets
```clarity
(contract-call? .in-game-asset-nft-minting batch-mint-eligible-assets)
```

#### Transfer Asset to Another Player
```clarity
(contract-call? .in-game-asset-nft-minting transfer u1 'ST1PLAYER1 'ST2PLAYER2)
```

### Read-Only Functions

#### Check Your Stats
```clarity
(contract-call? .in-game-asset-nft-minting get-player-stats 'ST1PLAYER)
```

#### View Asset Metadata
```clarity
(contract-call? .in-game-asset-nft-minting get-asset-metadata u1)
```

#### Check Eligible Events
```clarity
(contract-call? .in-game-asset-nft-minting get-player-eligible-events 'ST1PLAYER)
```

#### Get Game Status
```clarity
(contract-call? .in-game-asset-nft-minting get-game-status)
```

### Admin Functions

#### Initialize Game Events (Deploy Only)
```clarity
(contract-call? .in-game-asset-nft-minting initialize-game-events)
```

#### Mint Special Admin Asset
```clarity
(contract-call? .in-game-asset-nft-minting admin-mint-special 'ST1PLAYER "Special Reward" "trophy" "mythic")
```

#### Toggle Game Active State
```clarity
(contract-call? .in-game-asset-nft-minting toggle-game-state)
```

## 🏗️ Deployment Steps

1. **Deploy the contract**:
   ```bash
   clarinet deploy
   ```

2. **Initialize game events** (owner only):
   ```clarity
   (contract-call? .in-game-asset-nft-minting initialize-game-events)
   ```

3. **Players register**:
   ```clarity
   (contract-call? .in-game-asset-nft-minting register-player)
   ```

4. **Start playing and earning assets!** 🎯

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🔧 Development

This contract demonstrates:
- ✅ Non-fungible token implementation
- ✅ Event-driven minting logic
- ✅ Player progression tracking
- ✅ Dynamic metadata assignment
- ✅ Batch operations for efficiency
- ✅ Admin controls and permissions

## 📝 Contract Architecture

The system consists of:
- 🎨 **NFT Definition**: `game-asset` non-fungible token
- 📋 **Metadata Storage**: Asset details, player stats, and event configurations
- 🎯 **Event System**: Predefined achievements that trigger mints
- 🔐 **Access Control**: Owner permissions and player validations

## 🎯 Example Workflow

1. 👤 Player registers: `(register-player)`
2. 🎮 Player plays game and earns 60 points: `(update-player-score u60)`
3. 🏆 Player can now claim: First Kill (10pts), Treasure Hunter (30pts), Boss Defeat (50pts)
4. 💎 Player mints assets: `(batch-mint-eligible-assets)`
5. 🔄 Player continues playing to unlock legendary Dragon Slayer asset at 200pts!

## 📄 License

MIT License - Build amazing games! 🚀
