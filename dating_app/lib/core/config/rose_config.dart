import '../../data/models/subscription_models.dart';

/// Roses (spec: Hinge-style) — a limited, special-cased Like that always
/// reveals the sender to the receiver by name, bypassing the "who liked
/// you" blur/paywall for that one profile (see LikesScreen) even for a
/// Free receiver. The scarcity (one a day, free tier) is what makes
/// sending one mean something, same reasoning as real apps' rose caps.
int roseLimitFor(SubscriptionTier tier) => tier == SubscriptionTier.premium ? 3 : 1;
