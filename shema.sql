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
