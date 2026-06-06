-- Enable pg_trgm extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Trigram index for restaurant names (Fuzzy Search)
CREATE INDEX IF NOT EXISTS idx_restaurants_name_trgm ON restaurants USING gin (name gin_trgm_ops);

-- 2. Trigram index for dish mentions in reviews
CREATE INDEX IF NOT EXISTS idx_reviews_dish_mentions_trgm ON reviews USING gin (content gin_trgm_ops);

-- 3. B-tree index for restaurant scores/ratings for fast sorting
-- Using algorithm_score as it is the primary ranking metric
CREATE INDEX IF NOT EXISTS idx_restaurants_algorithm_score ON restaurants (algorithm_score DESC);

-- 4. GIST index for location-based queries
CREATE INDEX IF NOT EXISTS idx_restaurants_location ON restaurants USING gist (location);

-- 5. Index for user rewards lookups
CREATE INDEX IF NOT EXISTS idx_user_rewards_user_id ON user_rewards (user_id);

-- 6. Index for active notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_read ON notifications (user_id, is_read);

-- 7. Index for tier-based filtering
CREATE INDEX IF NOT EXISTS idx_profiles_tier ON profiles (tier);

-- 8. Index for category filtering on restaurants
CREATE INDEX IF NOT EXISTS idx_restaurants_category ON restaurants (category);

-- 9. Composite index for trending (votes + date)
CREATE INDEX IF NOT EXISTS idx_reviews_trending ON reviews (votes_count DESC, created_at DESC);

-- 10. Index for verification status
CREATE INDEX IF NOT EXISTS idx_profiles_verification_status ON profiles (verification_status);
