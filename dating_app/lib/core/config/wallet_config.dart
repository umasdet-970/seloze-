/// Coins/credits economy (spec: Badoo-style Superpowers) — a spendable
/// balance that lets a Free member buy one-off access to a Premium perk
/// (Boost, an extra Rose) without a subscription, on top of Premium
/// members already getting them free. Two ways to earn: a one-time
/// welcome credit, and a per-referral bonus (see referral_config.dart for
/// the discovery-bonus equivalent). Buying more with real money needs
/// RevenueCat, same "coming soon while billing is off" story as
/// paywall_screen.dart — see WalletScreen.
const int kWelcomeCoins = 100;
const int kCoinsPerReferral = 30;
const int kBoostCostCoins = 50;
const int kRoseCostCoins = 20;
