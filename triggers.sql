-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to check if user is blocked
CREATE OR REPLACE FUNCTION is_blocked(check_user_id UUID, against_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_blocks 
    WHERE (blocker_id = check_user_id AND blocked_id = against_user_id)
       OR (blocker_id = against_user_id AND blocked_id = check_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user reputation
CREATE OR REPLACE FUNCTION calculate_user_reputation(user_id UUID)
RETURNS INT AS $$
DECLARE
  rep INT := 0;
BEGIN
  -- +10 per post
  SELECT COUNT(*) * 10 INTO rep FROM posts WHERE author_id = user_id;
  -- +2 per like received
  SELECT rep + (COALESCE(SUM(likes_count), 0) * 2) INTO rep FROM posts WHERE author_id = user_id;
  -- +5 per comment
  SELECT rep + (COUNT(*) * 5) INTO rep FROM comments WHERE user_id = user_id AND NOT is_deleted;
  -- +50 per startup idea
  SELECT rep + (COUNT(*) * 50) INTO rep FROM startup_ideas WHERE founder_id = user_id;
  
  RETURN rep;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update reputation on profile
CREATE OR REPLACE FUNCTION update_profile_reputation()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles 
  SET reputation_score = calculate_user_reputation(NEW.author_id)
  WHERE id = NEW.author_id;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reputation_on_post
  AFTER INSERT OR UPDATE ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_reputation();

-- Function to get trending score for posts
CREATE OR REPLACE FUNCTION calculate_trending_score(post_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  age_hours DECIMAL;
  like_weight DECIMAL := 1.5;
  comment_weight DECIMAL := 1.0;
  view_weight DECIMAL := 0.1;
  post_record RECORD;
BEGIN
  SELECT 
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600 as hours,
    likes_count,
    comments_count,
    views_count
  INTO post_record
  FROM posts WHERE id = post_id;
  
  age_hours := GREATEST(post_record.hours, 1);
  
  RETURN (post_record.likes_count * like_weight + 
          post_record.comments_count * comment_weight + 
          post_record.views_count * view_weight) / POWER(age_hours + 2, 1.5);
END;
$$ LANGUAGE plpgsql;

-- Update trending scores periodically
CREATE OR REPLACE FUNCTION update_all_trending_scores()
RETURNS VOID AS $$
BEGIN
  UPDATE posts 
  SET trending_score = calculate_trending_score(id)
  WHERE created_at > NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;
