(define-non-fungible-token game-asset uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-game-not-active (err u102))
(define-constant err-invalid-event-type (err u103))
(define-constant err-event-already-claimed (err u104))
(define-constant err-insufficient-score (err u105))
(define-constant err-asset-not-found (err u106))
(define-constant err-player-not-registered (err u107))
(define-constant err-asset-not-listed (err u108))
(define-constant err-cannot-buy-own-asset (err u109))
(define-constant err-insufficient-payment (err u110))
(define-constant err-asset-already-listed (err u111))
(define-constant err-not-listed-owner (err u112))
(define-constant err-invalid-fusion-recipe (err u113))
(define-constant err-recipe-already-exists (err u114))
(define-constant err-recipe-not-active (err u115))
(define-constant err-asset-already-used (err u116))
(define-constant err-duplicate-input-assets (err u117))

(define-data-var last-token-id uint u0)
(define-data-var game-active bool true)
(define-data-var min-score-threshold uint u100)
(define-data-var marketplace-fee-percent uint u250)

(define-map asset-metadata
  uint
  {
    name: (string-ascii 64),
    asset-type: (string-ascii 32),
    rarity: (string-ascii 16),
    event-triggered: (string-ascii 64),
    mint-block: uint
  }
)

(define-map player-stats
  principal
  {
    total-score: uint,
    games-played: uint,
    achievements-unlocked: uint,
    last-activity: uint
  }
)

(define-map event-claims
  {player: principal, event-type: (string-ascii 64)}
  bool
)

(define-map game-events
  (string-ascii 64)
  {
    required-score: uint,
    asset-name: (string-ascii 64),
    asset-type: (string-ascii 32),
    rarity: (string-ascii 16),
    active: bool
  }
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint
  }
)

(define-map fusion-recipes
  (string-ascii 64)
  {
    input-type-1: (string-ascii 32),
    input-type-2: (string-ascii 32),
    output-name: (string-ascii 64),
    output-type: (string-ascii 32),
    output-rarity: (string-ascii 16),
    active: bool
  }
)

(define-map asset-fusion-history
  uint
  bool
)

(define-private (get-next-token-id)
  (let ((current-id (var-get last-token-id)))
    (var-set last-token-id (+ current-id u1))
    (+ current-id u1)
  )
)

(define-public (initialize-game-events)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set game-events "first-kill"
      {required-score: u10, asset-name: "Rookie Sword", asset-type: "weapon", rarity: "common", active: true})
    (map-set game-events "boss-defeat"
      {required-score: u50, asset-name: "Victory Crown", asset-type: "accessory", rarity: "rare", active: true})
    (map-set game-events "perfect-score"
      {required-score: u100, asset-name: "Flawless Crystal", asset-type: "gem", rarity: "epic", active: true})
    (map-set game-events "speed-run"
      {required-score: u75, asset-name: "Lightning Boots", asset-type: "armor", rarity: "rare", active: true})
    (map-set game-events "treasure-hunter"
      {required-score: u30, asset-name: "Golden Compass", asset-type: "tool", rarity: "uncommon", active: true})
    (map-set game-events "dragon-slayer"
      {required-score: u200, asset-name: "Dragon Scale Shield", asset-type: "armor", rarity: "legendary", active: true})
    (ok true)
  )
)

(define-public (register-player)
  (let ((player tx-sender))
    (ok (map-set player-stats player
      {total-score: u0, games-played: u0, achievements-unlocked: u0, last-activity: stacks-block-height}))
  )
)

(define-public (update-player-score (score uint))
  (let (
    (player tx-sender)
    (current-stats (default-to 
      {total-score: u0, games-played: u0, achievements-unlocked: u0, last-activity: stacks-block-height}
      (map-get? player-stats player)))
  )
    (asserts! (var-get game-active) err-game-not-active)
    (ok (map-set player-stats player
      {
        total-score: (+ (get total-score current-stats) score),
        games-played: (+ (get games-played current-stats) u1),
        achievements-unlocked: (get achievements-unlocked current-stats),
        last-activity: stacks-block-height
      }))
  )
)

(define-public (mint-asset-from-event (event-type (string-ascii 64)))
  (let (
    (player tx-sender)
    (token-id (get-next-token-id))
    (player-data (unwrap! (map-get? player-stats player) err-player-not-registered))
    (event-data (unwrap! (map-get? game-events event-type) err-invalid-event-type))
    (claim-key {player: player, event-type: event-type})
  )
    (asserts! (var-get game-active) err-game-not-active)
    (asserts! (get active event-data) err-invalid-event-type)
    (asserts! (>= (get total-score player-data) (get required-score event-data)) err-insufficient-score)
    (asserts! (is-none (map-get? event-claims claim-key)) err-event-already-claimed)
    
    (try! (nft-mint? game-asset token-id player))
    (map-set asset-metadata token-id
      {
        name: (get asset-name event-data),
        asset-type: (get asset-type event-data),
        rarity: (get rarity event-data),
        event-triggered: event-type,
        mint-block: stacks-block-height
      })
    (map-set event-claims claim-key true)
    (map-set player-stats player
      (merge player-data {achievements-unlocked: (+ (get achievements-unlocked player-data) u1)}))
    (ok token-id)
  )
)

(define-public (batch-mint-eligible-assets)
  (let ((player tx-sender))
    (asserts! (var-get game-active) err-game-not-active)
    (let ((player-data (unwrap! (map-get? player-stats player) err-player-not-registered)))
      (let ((total-score (get total-score player-data)))
        (let (
          (res1 (if (and (>= total-score u10) (is-none (map-get? event-claims {player: player, event-type: "first-kill"})))
                    (mint-asset-from-event "first-kill") (ok u0)))
          (res2 (if (and (>= total-score u30) (is-none (map-get? event-claims {player: player, event-type: "treasure-hunter"})))
                    (mint-asset-from-event "treasure-hunter") (ok u0)))
          (res3 (if (and (>= total-score u50) (is-none (map-get? event-claims {player: player, event-type: "boss-defeat"})))
                    (mint-asset-from-event "boss-defeat") (ok u0)))
          (res4 (if (and (>= total-score u75) (is-none (map-get? event-claims {player: player, event-type: "speed-run"})))
                    (mint-asset-from-event "speed-run") (ok u0)))
          (res5 (if (and (>= total-score u100) (is-none (map-get? event-claims {player: player, event-type: "perfect-score"})))
                    (mint-asset-from-event "perfect-score") (ok u0)))
          (res6 (if (and (>= total-score u200) (is-none (map-get? event-claims {player: player, event-type: "dragon-slayer"})))
                    (mint-asset-from-event "dragon-slayer") (ok u0)))
        )
          (ok u1)
        )
      )
    )
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender (unwrap! (nft-get-owner? game-asset token-id) err-asset-not-found))) err-not-token-owner)
    (nft-transfer? game-asset token-id sender recipient)
  )
)

(define-public (burn-asset (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? game-asset token-id) err-asset-not-found)))
    (asserts! (is-eq tx-sender owner) err-not-token-owner)
    (nft-burn? game-asset token-id owner)
  )
)

(define-public (admin-mint-special (recipient principal) (asset-name (string-ascii 64)) (asset-type (string-ascii 32)) (rarity (string-ascii 16)))
  (let ((token-id (get-next-token-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? game-asset token-id recipient))
    (map-set asset-metadata token-id
      {
        name: asset-name,
        asset-type: asset-type,
        rarity: rarity,
        event-triggered: "admin-special",
        mint-block: stacks-block-height
      })
    (ok token-id)
  )
)

(define-public (toggle-game-state)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set game-active (not (var-get game-active)))
    (ok (var-get game-active))
  )
)

(define-public (update-event (event-type (string-ascii 64)) (required-score uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((current-event (unwrap! (map-get? game-events event-type) err-invalid-event-type)))
      (map-set game-events event-type
        (merge current-event {required-score: required-score, active: active}))
      (ok true)
    )
  )
)

(define-read-only (get-asset-metadata (token-id uint))
  (map-get? asset-metadata token-id)
)

(define-read-only (get-player-stats (player principal))
  (map-get? player-stats player)
)

(define-read-only (get-event-info (event-type (string-ascii 64)))
  (map-get? game-events event-type)
)

(define-read-only (has-claimed-event (player principal) (event-type (string-ascii 64)))
  (is-some (map-get? event-claims {player: player, event-type: event-type}))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? game-asset token-id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-public (list-asset-for-sale (token-id uint) (price uint))
  (let ((asset-owner (unwrap! (nft-get-owner? game-asset token-id) err-asset-not-found)))
    (asserts! (is-eq tx-sender asset-owner) err-not-token-owner)
    (asserts! (is-none (map-get? marketplace-listings token-id)) err-asset-already-listed)
    (asserts! (> price u0) err-insufficient-payment)
    (map-set marketplace-listings token-id
      {
        seller: tx-sender,
        price: price,
        listed-at: stacks-block-height
      })
    (ok token-id)
  )
)

(define-public (remove-asset-listing (token-id uint))
  (let ((listing (unwrap! (map-get? marketplace-listings token-id) err-asset-not-listed)))
    (asserts! (is-eq tx-sender (get seller listing)) err-not-listed-owner)
    (map-delete marketplace-listings token-id)
    (ok token-id)
  )
)

(define-public (buy-listed-asset (token-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings token-id) err-asset-not-listed))
    (asset-owner (unwrap! (nft-get-owner? game-asset token-id) err-asset-not-found))
    (sale-price (get price listing))
    (marketplace-fee (/ (* sale-price (var-get marketplace-fee-percent)) u10000))
    (seller-payment (- sale-price marketplace-fee))
  )
    (asserts! (is-eq asset-owner (get seller listing)) err-not-listed-owner)
    (asserts! (not (is-eq tx-sender asset-owner)) err-cannot-buy-own-asset)
    (try! (stx-transfer? seller-payment tx-sender asset-owner))
    (try! (nft-transfer? game-asset token-id asset-owner tx-sender))
    (map-delete marketplace-listings token-id)
    (begin
      (if (> marketplace-fee u0)
        (try! (stx-transfer? marketplace-fee tx-sender contract-owner))
        true
      )
      (ok token-id)
    )
  )
)

(define-public (update-asset-price (token-id uint) (new-price uint))
  (let ((listing (unwrap! (map-get? marketplace-listings token-id) err-asset-not-listed)))
    (asserts! (is-eq tx-sender (get seller listing)) err-not-listed-owner)
    (asserts! (> new-price u0) err-insufficient-payment)
    (map-set marketplace-listings token-id
      (merge listing {price: new-price}))
    (ok token-id)
  )
)

(define-public (set-marketplace-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-percent u1000) err-insufficient-payment)
    (var-set marketplace-fee-percent new-fee-percent)
    (ok new-fee-percent)
  )
)

(define-read-only (get-game-status)
  {
    active: (var-get game-active),
    total-assets-minted: (var-get last-token-id),
    min-score-threshold: (var-get min-score-threshold),
    marketplace-fee-percent: (var-get marketplace-fee-percent)
  }
)

(define-read-only (get-player-eligible-events (player principal))
  (let ((player-data (default-to 
    {total-score: u0, games-played: u0, achievements-unlocked: u0, last-activity: u0}
    (map-get? player-stats player))))
    (let ((score (get total-score player-data)))
      {
        first-kill: (and (>= score u10) (not (has-claimed-event player "first-kill"))),
        treasure-hunter: (and (>= score u30) (not (has-claimed-event player "treasure-hunter"))),
        boss-defeat: (and (>= score u50) (not (has-claimed-event player "boss-defeat"))),
        speed-run: (and (>= score u75) (not (has-claimed-event player "speed-run"))),
        perfect-score: (and (>= score u100) (not (has-claimed-event player "perfect-score"))),
        dragon-slayer: (and (>= score u200) (not (has-claimed-event player "dragon-slayer")))
      }
    )
  )
)

(define-read-only (get-marketplace-listing (token-id uint))
  (map-get? marketplace-listings token-id)
)

(define-read-only (get-marketplace-fee-info)
  {
    fee-percent: (var-get marketplace-fee-percent),
    fee-recipient: contract-owner
  }
)

(define-public (create-fusion-recipe 
  (recipe-name (string-ascii 64))
  (input-type-1 (string-ascii 32))
  (input-type-2 (string-ascii 32))
  (output-name (string-ascii 64))
  (output-type (string-ascii 32))
  (output-rarity (string-ascii 16)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? fusion-recipes recipe-name)) err-recipe-already-exists)
    (map-set fusion-recipes recipe-name
      {
        input-type-1: input-type-1,
        input-type-2: input-type-2,
        output-name: output-name,
        output-type: output-type,
        output-rarity: output-rarity,
        active: true
      })
    (ok recipe-name)
  )
)

(define-public (toggle-recipe-status (recipe-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((recipe (unwrap! (map-get? fusion-recipes recipe-name) err-invalid-fusion-recipe)))
      (map-set fusion-recipes recipe-name
        (merge recipe {active: (not (get active recipe))}))
      (ok (not (get active recipe)))
    )
  )
)

(define-public (fuse-assets (token-id-1 uint) (token-id-2 uint) (recipe-name (string-ascii 64)))
  (let (
    (owner-1 (unwrap! (nft-get-owner? game-asset token-id-1) err-asset-not-found))
    (owner-2 (unwrap! (nft-get-owner? game-asset token-id-2) err-asset-not-found))
    (metadata-1 (unwrap! (map-get? asset-metadata token-id-1) err-asset-not-found))
    (metadata-2 (unwrap! (map-get? asset-metadata token-id-2) err-asset-not-found))
    (recipe (unwrap! (map-get? fusion-recipes recipe-name) err-invalid-fusion-recipe))
    (new-token-id (get-next-token-id))
  )
    (asserts! (is-eq tx-sender owner-1) err-not-token-owner)
    (asserts! (is-eq tx-sender owner-2) err-not-token-owner)
    (asserts! (not (is-eq token-id-1 token-id-2)) err-duplicate-input-assets)
    (asserts! (is-none (map-get? asset-fusion-history token-id-1)) err-asset-already-used)
    (asserts! (is-none (map-get? asset-fusion-history token-id-2)) err-asset-already-used)
    (asserts! (get active recipe) err-recipe-not-active)
    
    (asserts! 
      (or
        (and 
          (is-eq (get asset-type metadata-1) (get input-type-1 recipe))
          (is-eq (get asset-type metadata-2) (get input-type-2 recipe)))
        (and 
          (is-eq (get asset-type metadata-1) (get input-type-2 recipe))
          (is-eq (get asset-type metadata-2) (get input-type-1 recipe))))
      err-invalid-fusion-recipe)
    
    (try! (nft-burn? game-asset token-id-1 tx-sender))
    (try! (nft-burn? game-asset token-id-2 tx-sender))
    (map-set asset-fusion-history token-id-1 true)
    (map-set asset-fusion-history token-id-2 true)
    
    (try! (nft-mint? game-asset new-token-id tx-sender))
    (map-set asset-metadata new-token-id
      {
        name: (get output-name recipe),
        asset-type: (get output-type recipe),
        rarity: (get output-rarity recipe),
        event-triggered: "fusion",
        mint-block: stacks-block-height
      })
    (ok new-token-id)
  )
)

(define-public (initialize-fusion-recipes)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (create-fusion-recipe "sword-shield" "weapon" "armor" "Warrior's Aegis" "hybrid" "epic"))
    (try! (create-fusion-recipe "gem-tool" "gem" "tool" "Enchanted Finder" "magical-tool" "rare"))
    (try! (create-fusion-recipe "armor-accessory" "armor" "accessory" "Royal Battle Gear" "hybrid" "legendary"))
    (try! (create-fusion-recipe "weapon-gem" "weapon" "gem" "Crystalline Blade" "enchanted-weapon" "epic"))
    (ok true)
  )
)

(define-read-only (get-fusion-recipe (recipe-name (string-ascii 64)))
  (map-get? fusion-recipes recipe-name)
)

(define-read-only (is-asset-used-in-fusion (token-id uint))
  (default-to false (map-get? asset-fusion-history token-id))
)

(define-read-only (can-fuse-assets (token-id-1 uint) (token-id-2 uint) (recipe-name (string-ascii 64)))
  (let (
    (metadata-1-opt (map-get? asset-metadata token-id-1))
    (metadata-2-opt (map-get? asset-metadata token-id-2))
    (recipe-opt (map-get? fusion-recipes recipe-name))
  )
    (match metadata-1-opt metadata-1
      (match metadata-2-opt metadata-2
        (match recipe-opt recipe
          {
            valid: (and
              (get active recipe)
              (not (is-eq token-id-1 token-id-2))
              (is-none (map-get? asset-fusion-history token-id-1))
              (is-none (map-get? asset-fusion-history token-id-2))
              (or
                (and 
                  (is-eq (get asset-type metadata-1) (get input-type-1 recipe))
                  (is-eq (get asset-type metadata-2) (get input-type-2 recipe)))
                (and 
                  (is-eq (get asset-type metadata-1) (get input-type-2 recipe))
                  (is-eq (get asset-type metadata-2) (get input-type-1 recipe))))),
            recipe-active: (get active recipe),
            types-match: (or
              (and 
                (is-eq (get asset-type metadata-1) (get input-type-1 recipe))
                (is-eq (get asset-type metadata-2) (get input-type-2 recipe)))
              (and 
                (is-eq (get asset-type metadata-1) (get input-type-2 recipe))
                (is-eq (get asset-type metadata-2) (get input-type-1 recipe))))
          }
          {valid: false, recipe-active: false, types-match: false})
        {valid: false, recipe-active: false, types-match: false})
      {valid: false, recipe-active: false, types-match: false})
  )
)
