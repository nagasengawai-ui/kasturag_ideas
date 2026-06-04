-- =====================================================
-- IDEAHUB COMMUNITY - ENTERPRISE DATABASE SCHEMA
-- For 1M+ users with full features
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "citext";

-- =====================================================
-- CORE TABLES (Existing + Enhanced)
-- =====================================================

-- PROFILES (Enhanced)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  fullname TEXT NOT NULL,
  username CITEXT UNIQUE NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  cover_url TEXT,
  location TEXT,
  website TEXT,
  portfolio_urls TEXT[],
  skills TEXT[],
  interests TEXT[],
  social_links JSONB DEFAULT '{}',
  reputation_score INT DEFAULT 0,
  verification_badge BOOLEAN DEFAULT false,
  ranking_score DECIMAL DEFAULT 0,
  profile_views INT DEFAULT 0,
  followers_count INT DEFAULT 0,
  following_count INT DEFAULT 0,
  posts_count INT DEFAULT 0,
  is_admin BOOLEAN DEFAULT false,
  is_moderator BOOLEAN DEFAULT false,
  is_banned BOOLEAN DEFAULT false,
  ban_reason TEXT,
  ban_expires TIMESTAMPTZ,
  status TEXT DEFAULT 'active',
  join_date TIMESTAMPTZ DEFAULT NOW(),
  last_active TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  settings JSONB DEFAULT '{"email_notifications": true, "push_notifications": true}'
);

-- POSTS (Enhanced)
CREATE TABLE posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  content_html TEXT,
  excerpt TEXT,
  category TEXT NOT NULL,
  tags TEXT[],
  images TEXT[],
  attachments JSONB,
  video_url TEXT,
  document_urls TEXT[],
  poll_data JSONB,
  author_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  is_anonymous BOOLEAN DEFAULT false,
  is_draft BOOLEAN DEFAULT false,
  is_pinned BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  scheduled_for TIMESTAMPTZ,
  likes_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  shares_count INT DEFAULT 0,
  views_count INT DEFAULT 0,
  trending_score DECIMAL DEFAULT 0,
  edit_history JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  published_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

-- COMMUNITIES
CREATE TABLE communities (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  rules TEXT[],
  logo_url TEXT,
  banner_url TEXT,
  category TEXT,
  tags TEXT[],
  owner_id UUID REFERENCES profiles(id),
  members_count INT DEFAULT 0,
  posts_count INT DEFAULT 0,
  is_private BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- COMMUNITY MEMBERS
CREATE TABLE community_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  community_id UUID REFERENCES communities(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member', -- member, moderator, admin
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(community_id, user_id)
);

-- COMMENTS (Nested replies support)
CREATE TABLE comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  content_html TEXT,
  likes_count INT DEFAULT 0,
  replies_count INT DEFAULT 0,
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  path LTREE, -- For nested hierarchies
  level INT DEFAULT 0
);

-- LIKES (Unified for posts and comments)
CREATE TABLE likes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  target_type TEXT CHECK (target_type IN ('post', 'comment')),
  target_id UUID NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(target_type, target_id, user_id)
);

-- FOLLOWERS
CREATE TABLE followers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  follower_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id)
);

-- =====================================================
-- MESSAGING SYSTEM
-- =====================================================

-- CONVERSATIONS
CREATE TABLE conversations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  type TEXT DEFAULT 'direct', -- direct, group
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CONVERSATION PARTICIPANTS
CREATE TABLE conversation_participants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  last_read_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(conversation_id, user_id)
);

-- MESSAGES
CREATE TABLE messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT,
  attachments JSONB,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- NOTIFICATION SYSTEM
-- =====================================================

CREATE TABLE notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT CHECK (type IN ('like', 'comment', 'follow', 'mention', 'reply', 'message', 'achievement', 'system')),
  content TEXT NOT NULL,
  reference_type TEXT, -- post, comment, user, message
  reference_id UUID,
  is_read BOOLEAN DEFAULT false,
  is_emailed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'
);

-- NOTIFICATION SETTINGS
CREATE TABLE notification_settings (
  user_id UUID REFERENCES profiles(id) PRIMARY KEY,
  email_likes BOOLEAN DEFAULT true,
  email_comments BOOLEAN DEFAULT true,
  email_follows BOOLEAN DEFAULT true,
  email_messages BOOLEAN DEFAULT true,
  push_likes BOOLEAN DEFAULT true,
  push_comments BOOLEAN DEFAULT true,
  push_follows BOOLEAN DEFAULT true,
  push_messages BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- GAMIFICATION SYSTEM
-- =====================================================

-- BADGES
CREATE TABLE badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  icon_url TEXT,
  category TEXT,
  points_reward INT DEFAULT 0,
  requirements JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- USER BADGES
CREATE TABLE user_badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  badge_id UUID REFERENCES badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

-- ACHIEVEMENTS
CREATE TABLE achievements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  xp_reward INT DEFAULT 0,
  criteria JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- USER ACHIEVEMENTS
CREATE TABLE user_achievements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
  progress INT DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  UNIQUE(user_id, achievement_id)
);

-- USER ACTIVITY LOG (for XP)
CREATE TABLE user_activity (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  activity_type TEXT,
  xp_earned INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- DAILY STREAKS
CREATE TABLE daily_streaks (
  user_id UUID REFERENCES profiles(id) PRIMARY KEY,
  current_streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  last_activity_date DATE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- STARTUP & JOB FEATURES
-- =====================================================

-- STARTUP IDEAS
CREATE TABLE startup_ideas (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  problem TEXT,
  solution TEXT,
  market_size TEXT,
  funding_stage TEXT,
  looking_for TEXT[],
  founder_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  likes_count INT DEFAULT 0,
  views_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STARTUP TEAM MEMBERS
CREATE TABLE startup_team_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  startup_id UUID REFERENCES startup_ideas(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role TEXT,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(startup_id, user_id)
);

-- JOB POSTINGS
CREATE TABLE jobs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  company_name TEXT,
  company_logo TEXT,
  location TEXT,
  job_type TEXT, -- full-time, part-time, remote, internship
  description TEXT,
  requirements TEXT[],
  salary_range TEXT,
  posted_by UUID REFERENCES profiles(id),
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- JOB APPLICATIONS
CREATE TABLE job_applications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
  applicant_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  resume_url TEXT,
  cover_letter TEXT,
  status TEXT DEFAULT 'pending',
  applied_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(job_id, applicant_id)
);

-- =====================================================
-- EVENTS SYSTEM
-- =====================================================

CREATE TABLE events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT, -- tech, hackathon, meetup, webinar
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  location TEXT,
  virtual_link TEXT,
  max_attendees INT,
  image_url TEXT,
  organizer_id UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE event_registrations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  attended BOOLEAN DEFAULT false,
  UNIQUE(event_id, user_id)
);

-- =====================================================
-- MODERATION & SECURITY
-- =====================================================

-- REPORTS
CREATE TABLE reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  reporter_id UUID REFERENCES profiles(id),
  target_type TEXT CHECK (target_type IN ('post', 'comment', 'user', 'message')),
  target_id UUID NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'pending', -- pending, reviewed, dismissed, action_taken
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id)
);

-- USER BLOCKS
CREATE TABLE user_blocks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  blocker_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

-- USER MUTES
CREATE TABLE user_mutes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  muter_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  muted_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(muter_id, muted_id)
);

-- AUDIT LOGS
CREATE TABLE audit_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  target_type TEXT,
  target_id UUID,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- MODERATION LOGS
CREATE TABLE moderation_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  moderator_id UUID REFERENCES profiles(id),
  action TEXT,
  target_type TEXT,
  target_id UUID,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- ANALYTICS & VIEWS
-- =====================================================

CREATE TABLE post_views (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  viewer_id UUID REFERENCES profiles(id),
  viewer_ip INET,
  viewed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE profile_views (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  viewer_id UUID REFERENCES profiles(id),
  viewer_ip INET,
  viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX idx_posts_author ON posts(author_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_posts_created ON posts(created_at DESC);
CREATE INDEX idx_posts_trending ON posts(trending_score DESC);
CREATE INDEX idx_posts_category ON posts(category);
CREATE INDEX idx_posts_tags ON posts USING GIN(tags);
CREATE INDEX idx_posts_search ON posts USING GIN(to_tsvector('english', title || ' ' || content));
CREATE INDEX idx_comments_post ON comments(post_id) WHERE NOT is_deleted;
CREATE INDEX idx_comments_parent ON comments(parent_id);
CREATE INDEX idx_comments_path ON comments USING GIST(path);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX idx_followers_following ON followers(following_id);
CREATE INDEX idx_likes_target ON likes(target_type, target_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_profiles_username ON profiles(username);
CREATE INDEX idx_profiles_ranking ON profiles(ranking_score DESC);
CREATE INDEX idx_jobs_active ON jobs(is_active, expires_at);
CREATE INDEX idx_events_date ON events(start_date);

-- =====================================================
-- IDEAHUB COMMUNITY - COMPLETE ENTERPRISE SCHEMA
-- All tables with proper constraints, indexes, and triggers
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "ltree";

-- =====================================================
-- 1. COMMENTS (Enhanced with nested replies)
-- =====================================================
DROP TABLE IF EXISTS comments CASCADE;
CREATE TABLE comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID NOT NULL,
  user_id UUID NOT NULL,
  parent_id UUID,
  content TEXT NOT NULL,
  content_html TEXT,
  likes_count INT DEFAULT 0,
  replies_count INT DEFAULT 0,
  is_edited BOOLEAN DEFAULT false,
  is_deleted BOOLEAN DEFAULT false,
  edit_history JSONB DEFAULT '[]',
  path LTREE,
  level INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_comment_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_comment_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_comment_parent FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

-- Indexes for comments
CREATE INDEX idx_comments_post ON comments(post_id) WHERE NOT is_deleted;
CREATE INDEX idx_comments_user ON comments(user_id);
CREATE INDEX idx_comments_parent ON comments(parent_id);
CREATE INDEX idx_comments_path ON comments USING GIST(path);
CREATE INDEX idx_comments_created ON comments(created_at DESC);
CREATE INDEX idx_comments_likes ON comments(likes_count DESC);

-- Trigger to update path for nested comments
CREATE OR REPLACE FUNCTION update_comment_path()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.path = text2ltree(NEW.id::text);
    NEW.level = 0;
  ELSE
    SELECT path INTO NEW.path FROM comments WHERE id = NEW.parent_id;
    NEW.path = NEW.path || text2ltree(NEW.id::text);
    NEW.level = nlevel(NEW.path) - 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_comment_path
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_path();

-- =====================================================
-- 2. LIKES (Unified for posts and comments)
-- =====================================================
DROP TABLE IF EXISTS likes CASCADE;
CREATE TABLE likes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment')),
  target_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_like_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(target_type, target_id, user_id)
);

-- Indexes for likes
CREATE INDEX idx_likes_target ON likes(target_type, target_id);
CREATE INDEX idx_likes_user ON likes(user_id);
CREATE INDEX idx_likes_created ON likes(created_at DESC);

-- =====================================================
-- 3. FOLLOWERS
-- =====================================================
DROP TABLE IF EXISTS followers CASCADE;
CREATE TABLE followers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  follower_id UUID NOT NULL,
  following_id UUID NOT NULL,
  status TEXT DEFAULT 'pending', -- pending, accepted, blocked
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_follower_user FOREIGN KEY (follower_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_following_user FOREIGN KEY (following_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(follower_id, following_id),
  CONSTRAINT different_users CHECK (follower_id != following_id)
);

-- Indexes for followers
CREATE INDEX idx_followers_follower ON followers(follower_id);
CREATE INDEX idx_followers_following ON followers(following_id);
CREATE INDEX idx_followers_status ON followers(status);
CREATE INDEX idx_followers_created ON followers(created_at DESC);

-- =====================================================
-- 4. SAVED POSTS
-- =====================================================
DROP TABLE IF EXISTS saved_posts CASCADE;
CREATE TABLE saved_posts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL,
  post_id UUID NOT NULL,
  collection_name TEXT DEFAULT 'default',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_saved_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_saved_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  UNIQUE(user_id, post_id)
);

-- Indexes for saved posts
CREATE INDEX idx_saved_posts_user ON saved_posts(user_id);
CREATE INDEX idx_saved_posts_post ON saved_posts(post_id);
CREATE INDEX idx_saved_posts_collection ON saved_posts(collection_name);
CREATE INDEX idx_saved_posts_created ON saved_posts(created_at DESC);

-- =====================================================
-- 5. COMMUNITY MEMBERS
-- =====================================================
DROP TABLE IF EXISTS community_members CASCADE;
CREATE TABLE community_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  community_id UUID NOT NULL,
  user_id UUID NOT NULL,
  role TEXT DEFAULT 'member', -- member, moderator, admin, owner
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  contribution_score INT DEFAULT 0,
  
  CONSTRAINT fk_community_member_community FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE,
  CONSTRAINT fk_community_member_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(community_id, user_id)
);

-- Indexes for community members
CREATE INDEX idx_community_members_community ON community_members(community_id);
CREATE INDEX idx_community_members_user ON community_members(user_id);
CREATE INDEX idx_community_members_role ON community_members(role);
CREATE INDEX idx_community_members_score ON community_members(contribution_score DESC);

-- =====================================================
-- 6. CONVERSATION PARTICIPANTS
-- =====================================================
DROP TABLE IF EXISTS conversation_participants CASCADE;
CREATE TABLE conversation_participants (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  conversation_id UUID NOT NULL,
  user_id UUID NOT NULL,
  last_read_at TIMESTAMPTZ DEFAULT NOW(),
  last_delivered_at TIMESTAMPTZ,
  is_typing BOOLEAN DEFAULT false,
  typing_updated_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  left_at TIMESTAMPTZ,
  muted_until TIMESTAMPTZ,
  
  CONSTRAINT fk_participant_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_participant_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(conversation_id, user_id)
);

-- Indexes for conversation participants
CREATE INDEX idx_participants_conversation ON conversation_participants(conversation_id);
CREATE INDEX idx_participants_user ON conversation_participants(user_id);
CREATE INDEX idx_participants_last_read ON conversation_participants(last_read_at);
CREATE INDEX idx_participants_typing ON conversation_participants(is_typing);

-- =====================================================
-- 7. NOTIFICATION SETTINGS
-- =====================================================
DROP TABLE IF EXISTS notification_settings CASCADE;
CREATE TABLE notification_settings (
  user_id UUID PRIMARY KEY,
  email_likes BOOLEAN DEFAULT true,
  email_comments BOOLEAN DEFAULT true,
  email_follows BOOLEAN DEFAULT true,
  email_messages BOOLEAN DEFAULT true,
  email_mentions BOOLEAN DEFAULT true,
  email_replies BOOLEAN DEFAULT true,
  email_achievements BOOLEAN DEFAULT true,
  push_likes BOOLEAN DEFAULT true,
  push_comments BOOLEAN DEFAULT true,
  push_follows BOOLEAN DEFAULT true,
  push_messages BOOLEAN DEFAULT true,
  push_mentions BOOLEAN DEFAULT true,
  push_replies BOOLEAN DEFAULT true,
  push_achievements BOOLEAN DEFAULT true,
  in_app_likes BOOLEAN DEFAULT true,
  in_app_comments BOOLEAN DEFAULT true,
  in_app_follows BOOLEAN DEFAULT true,
  in_app_messages BOOLEAN DEFAULT true,
  in_app_mentions BOOLEAN DEFAULT true,
  notification_sound BOOLEAN DEFAULT true,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_notification_settings_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE
);

-- =====================================================
-- 8. BADGES
-- =====================================================
DROP TABLE IF EXISTS badges CASCADE;
CREATE TABLE badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  icon_url TEXT,
  badge_type TEXT CHECK (badge_type IN ('bronze', 'silver', 'gold', 'platinum', 'special')),
  category TEXT, -- contributor, expert, community, event, special
  points_reward INT DEFAULT 0,
  requirements JSONB, -- { type: "posts_count", target: 100, timeframe: "all_time" }
  is_hidden BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for badges
CREATE INDEX idx_badges_type ON badges(badge_type);
CREATE INDEX idx_badges_category ON badges(category);
CREATE INDEX idx_badges_points ON badges(points_reward DESC);

-- =====================================================
-- 9. USER BADGES
-- =====================================================
DROP TABLE IF EXISTS user_badges CASCADE;
CREATE TABLE user_badges (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL,
  badge_id UUID NOT NULL,
  progress INT DEFAULT 0,
  earned_at TIMESTAMPTZ,
  shown_at TIMESTAMPTZ,
  
  CONSTRAINT fk_user_badge_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_user_badge_badge FOREIGN KEY (badge_id) REFERENCES badges(id) ON DELETE CASCADE,
  UNIQUE(user_id, badge_id)
);

-- Indexes for user badges
CREATE INDEX idx_user_badges_user ON user_badges(user_id);
CREATE INDEX idx_user_badges_badge ON user_badges(badge_id);
CREATE INDEX idx_user_badges_earned ON user_badges(earned_at DESC);
CREATE INDEX idx_user_badges_progress ON user_badges(progress);

-- =====================================================
-- 10. ACHIEVEMENTS
-- =====================================================
DROP TABLE IF EXISTS achievements CASCADE;
CREATE TABLE achievements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  xp_reward INT DEFAULT 0,
  coins_reward INT DEFAULT 0,
  badge_id UUID,
  criteria_type TEXT NOT NULL, -- posts, likes, comments, followers, days_active, etc.
  criteria_target INT NOT NULL,
  criteria_timeframe TEXT, -- all_time, daily, weekly, monthly
  is_repeatable BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_achievement_badge FOREIGN KEY (badge_id) REFERENCES badges(id)
);

-- Indexes for achievements
CREATE INDEX idx_achievements_criteria ON achievements(criteria_type, criteria_target);
CREATE INDEX idx_achievements_xp ON achievements(xp_reward DESC);

-- =====================================================
-- 11. USER ACHIEVEMENTS
-- =====================================================
DROP TABLE IF EXISTS user_achievements CASCADE;
CREATE TABLE user_achievements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL,
  achievement_id UUID NOT NULL,
  progress INT DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  times_completed INT DEFAULT 1,
  
  CONSTRAINT fk_user_achievement_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_user_achievement_achievement FOREIGN KEY (achievement_id) REFERENCES achievements(id) ON DELETE CASCADE,
  UNIQUE(user_id, achievement_id)
);

-- Indexes for user achievements
CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_completed ON user_achievements(completed, completed_at DESC);
CREATE INDEX idx_user_achievements_progress ON user_achievements(progress);

-- =====================================================
-- 12. STARTUP IDEAS
-- =====================================================
DROP TABLE IF EXISTS startup_ideas CASCADE;
CREATE TABLE startup_ideas (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  tagline TEXT,
  description TEXT,
  problem TEXT,
  solution TEXT,
  market_size TEXT,
  business_model TEXT,
  competitors TEXT[],
  target_audience TEXT[],
  funding_stage TEXT CHECK (funding_stage IN ('idea', 'pre-seed', 'seed', 'series_a', 'series_b', 'growth', 'exit')),
  funding_asked DECIMAL,
  looking_for TEXT[], -- cofounder, developer, marketer, investor
  pitch_deck_url TEXT,
  video_url TEXT,
  website_url TEXT,
  founder_id UUID NOT NULL,
  likes_count INT DEFAULT 0,
  views_count INT DEFAULT 0,
  is_featured BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'active', -- active, funded, closed, archived
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_startup_founder FOREIGN KEY (founder_id) REFERENCES profiles(id) ON DELETE CASCADE
);

-- Indexes for startup ideas
CREATE INDEX idx_startup_founder ON startup_ideas(founder_id);
CREATE INDEX idx_startup_funding ON startup_ideas(funding_stage);
CREATE INDEX idx_startup_likes ON startup_ideas(likes_count DESC);
CREATE INDEX idx_startup_created ON startup_ideas(created_at DESC);
CREATE INDEX idx_startup_status ON startup_ideas(status);
CREATE INDEX idx_startup_search ON startup_ideas USING GIN(to_tsvector('english', title || ' ' || description));

-- =====================================================
-- 13. STARTUP TEAM MEMBERS
-- =====================================================
DROP TABLE IF EXISTS startup_team_members CASCADE;
CREATE TABLE startup_team_members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  startup_id UUID NOT NULL,
  user_id UUID NOT NULL,
  role TEXT NOT NULL, -- founder, cofounder, advisor, investor, team_member
  equity_percentage DECIMAL,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  
  CONSTRAINT fk_team_startup FOREIGN KEY (startup_id) REFERENCES startup_ideas(id) ON DELETE CASCADE,
  CONSTRAINT fk_team_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(startup_id, user_id)
);

-- Indexes for startup team members
CREATE INDEX idx_team_startup ON startup_team_members(startup_id);
CREATE INDEX idx_team_user ON startup_team_members(user_id);
CREATE INDEX idx_team_role ON startup_team_members(role);

-- =====================================================
-- 14. JOBS
-- =====================================================
DROP TABLE IF EXISTS jobs CASCADE;
CREATE TABLE jobs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  company_name TEXT NOT NULL,
  company_logo TEXT,
  company_website TEXT,
  location TEXT,
  location_type TEXT CHECK (location_type IN ('remote', 'onsite', 'hybrid')),
  job_type TEXT CHECK (job_type IN ('full-time', 'part-time', 'contract', 'internship', 'freelance')),
  experience_level TEXT CHECK (experience_level IN ('entry', 'junior', 'mid', 'senior', 'lead', 'executive')),
  salary_min DECIMAL,
  salary_max DECIMAL,
  salary_currency TEXT DEFAULT 'USD',
  description TEXT NOT NULL,
  requirements TEXT[],
  responsibilities TEXT[],
  benefits TEXT[],
  skills_required TEXT[],
  posted_by UUID NOT NULL,
  is_active BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_job_poster FOREIGN KEY (posted_by) REFERENCES profiles(id) ON DELETE CASCADE
);

-- Indexes for jobs
CREATE INDEX idx_jobs_active ON jobs(is_active, expires_at);
CREATE INDEX idx_jobs_type ON jobs(job_type);
CREATE INDEX idx_jobs_location ON jobs(location_type);
CREATE INDEX idx_jobs_created ON jobs(created_at DESC);
CREATE INDEX idx_jobs_company ON jobs(company_name);
CREATE INDEX idx_jobs_skills ON jobs USING GIN(skills_required);
CREATE INDEX idx_jobs_search ON jobs USING GIN(to_tsvector('english', title || ' ' || description));

-- =====================================================
-- 15. JOB APPLICATIONS
-- =====================================================
DROP TABLE IF EXISTS job_applications CASCADE;
CREATE TABLE job_applications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  job_id UUID NOT NULL,
  applicant_id UUID NOT NULL,
  resume_url TEXT NOT NULL,
  cover_letter TEXT,
  portfolio_url TEXT,
  linkedin_url TEXT,
  github_url TEXT,
  status TEXT DEFAULT 'pending', -- pending, reviewed, shortlisted, rejected, hired
  notes TEXT,
  reviewer_id UUID,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_application_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
  CONSTRAINT fk_application_applicant FOREIGN KEY (applicant_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_application_reviewer FOREIGN KEY (reviewer_id) REFERENCES profiles(id),
  UNIQUE(job_id, applicant_id)
);

-- Indexes for job applications
CREATE INDEX idx_applications_job ON job_applications(job_id);
CREATE INDEX idx_applications_applicant ON job_applications(applicant_id);
CREATE INDEX idx_applications_status ON job_applications(status);
CREATE INDEX idx_applications_created ON job_applications(created_at DESC);

-- =====================================================
-- 16. EVENTS
-- =====================================================
DROP TABLE IF EXISTS events CASCADE;
CREATE TABLE events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  event_type TEXT CHECK (event_type IN ('tech', 'hackathon', 'meetup', 'webinar', 'conference', 'workshop', 'networking')),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  timezone TEXT DEFAULT 'UTC',
  location TEXT,
  venue_name TEXT,
  address TEXT,
  virtual_link TEXT,
  max_attendees INT,
  current_attendees INT DEFAULT 0,
  price DECIMAL DEFAULT 0,
  currency TEXT DEFAULT 'USD',
  image_url TEXT,
  banner_url TEXT,
  agenda JSONB, -- array of sessions
  speakers JSONB, -- array of speaker objects
  organizer_id UUID NOT NULL,
  is_free BOOLEAN DEFAULT true,
  is_featured BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'upcoming', -- upcoming, ongoing, completed, cancelled
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_event_organizer FOREIGN KEY (organizer_id) REFERENCES profiles(id) ON DELETE CASCADE
);

-- Indexes for events
CREATE INDEX idx_events_start_date ON events(start_date);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_featured ON events(is_featured);
CREATE INDEX idx_events_slug ON events(slug);
CREATE INDEX idx_events_search ON events USING GIN(to_tsvector('english', title || ' ' || description));

-- =====================================================
-- 17. EVENT REGISTRATIONS
-- =====================================================
DROP TABLE IF EXISTS event_registrations CASCADE;
CREATE TABLE event_registrations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id UUID NOT NULL,
  user_id UUID NOT NULL,
  ticket_type TEXT DEFAULT 'general',
  ticket_number TEXT UNIQUE,
  checked_in BOOLEAN DEFAULT false,
  checked_in_at TIMESTAMPTZ,
  payment_status TEXT DEFAULT 'pending', -- pending, completed, refunded
  payment_id TEXT,
  registration_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_registration_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  CONSTRAINT fk_registration_user FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(event_id, user_id)
);

-- Indexes for event registrations
CREATE INDEX idx_registrations_event ON event_registrations(event_id);
CREATE INDEX idx_registrations_user ON event_registrations(user_id);
CREATE INDEX idx_registrations_checkin ON event_registrations(checked_in);
CREATE INDEX idx_registrations_payment ON event_registrations(payment_status);
CREATE INDEX idx_registrations_ticket ON event_registrations(ticket_number);

-- =====================================================
-- 18. REPORTS
-- =====================================================
DROP TABLE IF EXISTS reports CASCADE;
CREATE TABLE reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  reporter_id UUID NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'comment', 'user', 'message', 'startup', 'job', 'event')),
  target_id UUID NOT NULL,
  reason_category TEXT CHECK (reason_category IN ('spam', 'harassment', 'hate_speech', 'violence', 'nsfw', 'copyright', 'impersonation', 'misinformation', 'other')),
  reason TEXT,
  evidence_urls TEXT[],
  status TEXT DEFAULT 'pending', -- pending, reviewing, dismissed, action_taken
  priority INT DEFAULT 1, -- 1-5, 5 highest
  assigned_to UUID,
  resolution_notes TEXT,
  action_taken TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID,
  
  CONSTRAINT fk_report_reporter FOREIGN KEY (reporter_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_report_assignee FOREIGN KEY (assigned_to) REFERENCES profiles(id),
  CONSTRAINT fk_report_resolver FOREIGN KEY (resolved_by) REFERENCES profiles(id)
);

-- Indexes for reports
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_priority ON reports(priority);
CREATE INDEX idx_reports_created ON reports(created_at DESC);
CREATE INDEX idx_reports_reporter ON reports(reporter_id);

-- =====================================================
-- 19. USER BLOCKS
-- =====================================================
DROP TABLE IF EXISTS user_blocks CASCADE;
CREATE TABLE user_blocks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  blocker_id UUID NOT NULL,
  blocked_id UUID NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  CONSTRAINT fk_block_blocker FOREIGN KEY (blocker_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_block_blocked FOREIGN KEY (blocked_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(blocker_id, blocked_id),
  CONSTRAINT different_users_block CHECK (blocker_id != blocked_id)
);

-- Indexes for user blocks
CREATE INDEX idx_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON user_blocks(blocked_id);
CREATE INDEX idx_blocks_expires ON user_blocks(expires_at);

-- =====================================================
-- 20. USER MUTES
-- =====================================================
DROP TABLE IF EXISTS user_mutes CASCADE;
CREATE TABLE user_mutes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  muter_id UUID NOT NULL,
  muted_id UUID NOT NULL,
  duration_days INT DEFAULT 30,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  CONSTRAINT fk_mute_muter FOREIGN KEY (muter_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_mute_muted FOREIGN KEY (muted_id) REFERENCES profiles(id) ON DELETE CASCADE,
  UNIQUE(muter_id, muted_id),
  CONSTRAINT different_users_mute CHECK (muter_id != muted_id)
);

-- Indexes for user mutes
CREATE INDEX idx_mutes_muter ON user_mutes(muter_id);
CREATE INDEX idx_mutes_muted ON user_mutes(muted_id);
CREATE INDEX idx_mutes_expires ON user_mutes(expires_at);

-- =====================================================
-- 21. AUDIT LOGS
-- =====================================================
DROP TABLE IF EXISTS audit_logs CASCADE;
CREATE TABLE audit_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  request_id UUID,
  session_id TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES profiles(id)
);

-- Indexes for audit logs
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_target ON audit_logs(target_type, target_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_ip ON audit_logs(ip_address);
CREATE INDEX idx_audit_request ON audit_logs(request_id);

-- =====================================================
-- 22. MODERATION LOGS
-- =====================================================
DROP TABLE IF EXISTS moderation_logs CASCADE;
CREATE TABLE moderation_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  moderator_id UUID NOT NULL,
  action TEXT NOT NULL, -- warn, mute, block, ban, delete_content, restore_content
  target_type TEXT NOT NULL,
  target_id UUID NOT NULL,
  reason TEXT,
  duration INT, -- for temporary actions in days
  previous_status TEXT,
  new_status TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_mod_log_moderator FOREIGN KEY (moderator_id) REFERENCES profiles(id)
);

-- Indexes for moderation logs
CREATE INDEX idx_mod_logs_moderator ON moderation_logs(moderator_id);
CREATE INDEX idx_mod_logs_target ON moderation_logs(target_type, target_id);
CREATE INDEX idx_mod_logs_action ON moderation_logs(action);
CREATE INDEX idx_mod_logs_created ON moderation_logs(created_at DESC);

-- =====================================================
-- 23. POST VIEWS
-- =====================================================
DROP TABLE IF EXISTS post_views CASCADE;
CREATE TABLE post_views (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  post_id UUID NOT NULL,
  viewer_id UUID,
  viewer_ip INET,
  user_agent TEXT,
  referrer TEXT,
  view_duration INT, -- seconds
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_view_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_view_user FOREIGN KEY (viewer_id) REFERENCES profiles(id)
);

-- Indexes for post views
CREATE INDEX idx_post_views_post ON post_views(post_id);
CREATE INDEX idx_post_views_user ON post_views(viewer_id);
CREATE INDEX idx_post_views_created ON post_views(created_at DESC);
CREATE INDEX idx_post_views_ip ON post_views(viewer_ip);

-- =====================================================
-- 24. PROFILE VIEWS
-- =====================================================
DROP TABLE IF EXISTS profile_views CASCADE;
CREATE TABLE profile_views (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  profile_id UUID NOT NULL,
  viewer_id UUID,
  viewer_ip INET,
  user_agent TEXT,
  referrer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT fk_profile_view_profile FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_profile_view_user FOREIGN KEY (viewer_id) REFERENCES profiles(id)
);

-- Indexes for profile views
CREATE INDEX idx_profile_views_profile ON profile_views(profile_id);
CREATE INDEX idx_profile_views_user ON profile_views(viewer_id);
CREATE INDEX idx_profile_views_created ON profile_views(created_at DESC);

-- =====================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_followers_updated_at BEFORE UPDATE ON followers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_startup_ideas_updated_at BEFORE UPDATE ON startup_ideas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update comments count on posts
CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' AND OLD.is_deleted = false THEN
    UPDATE posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_post_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_post_comments_count();

-- Update likes count
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.target_type = 'post' THEN
      UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.target_id;
    ELSIF NEW.target_type = 'comment' THEN
      UPDATE comments SET likes_count = likes_count + 1 WHERE id = NEW.target_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.target_type = 'post' THEN
      UPDATE posts SET likes_count = likes_count - 1 WHERE id = OLD.target_id;
    ELSIF OLD.target_type = 'comment' THEN
      UPDATE comments SET likes_count = likes_count - 1 WHERE id = OLD.target_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW
  EXECUTE FUNCTION update_likes_count();
