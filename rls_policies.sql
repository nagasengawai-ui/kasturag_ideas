-- =====================================================
-- ROW LEVEL SECURITY POLICIES - All Tables
-- =====================================================

-- Enable RLS on all tables
DO $$ 
DECLARE
  tables TEXT[] := ARRAY['comments', 'likes', 'followers', 'saved_posts', 'community_members', 
                          'conversation_participants', 'notification_settings', 'badges', 'user_badges',
                          'achievements', 'user_achievements', 'startup_ideas', 'startup_team_members',
                          'jobs', 'job_applications', 'events', 'event_registrations', 'reports',
                          'user_blocks', 'user_mutes', 'audit_logs', 'moderation_logs', 'post_views', 'profile_views'];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- =====================================================
-- COMMENTS Policies
-- =====================================================
CREATE POLICY "Comments viewable by everyone" ON comments FOR SELECT USING (NOT is_deleted);
CREATE POLICY "Users can create comments" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own comments" ON comments FOR UPDATE USING (auth.uid() = user_id AND NOT is_deleted);
CREATE POLICY "Users can delete own comments" ON comments FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage comments" ON comments FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- =====================================================
-- LIKES Policies
-- =====================================================
CREATE POLICY "Likes viewable by everyone" ON likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can like" ON likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove own likes" ON likes FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- FOLLOWERS Policies
-- =====================================================
CREATE POLICY "Followers viewable by everyone" ON followers FOR SELECT USING (status = 'accepted');
CREATE POLICY "Users can follow others" ON followers FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON followers FOR DELETE USING (auth.uid() = follower_id);
CREATE POLICY "Users can update follow status" ON followers FOR UPDATE USING (auth.uid() = following_id);

-- =====================================================
-- SAVED POSTS Policies
-- =====================================================
CREATE POLICY "Users can view own saved posts" ON saved_posts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can save posts" ON saved_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove saved posts" ON saved_posts FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- COMMUNITY MEMBERS Policies
-- =====================================================
CREATE POLICY "Community members viewable by everyone" ON community_members FOR SELECT USING (true);
CREATE POLICY "Users can join communities" ON community_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave communities" ON community_members FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Moderators can manage members" ON community_members FOR UPDATE USING (
  EXISTS (SELECT 1 FROM community_members WHERE community_id = community_members.community_id AND user_id = auth.uid() AND role IN ('moderator', 'admin', 'owner'))
);

-- =====================================================
-- CONVERSATION PARTICIPANTS Policies
-- =====================================================
CREATE POLICY "Users can view own conversations" ON conversation_participants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can join conversations" ON conversation_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own participation" ON conversation_participants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can leave conversations" ON conversation_participants FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- NOTIFICATION SETTINGS Policies
-- =====================================================
CREATE POLICY "Users can view own notification settings" ON notification_settings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notification settings" ON notification_settings FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own notification settings" ON notification_settings FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- BADGES Policies (Public read)
-- =====================================================
CREATE POLICY "Badges viewable by everyone" ON badges FOR SELECT USING (true);
CREATE POLICY "Only admins can manage badges" ON badges FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- =====================================================
-- USER BADGES Policies
-- =====================================================
CREATE POLICY "User badges viewable by everyone" ON user_badges FOR SELECT USING (true);
CREATE POLICY "System can award badges" ON user_badges FOR INSERT WITH CHECK (true);

-- =====================================================
-- ACHIEVEMENTS Policies
-- =====================================================
CREATE POLICY "Achievements viewable by everyone" ON achievements FOR SELECT USING (true);
CREATE POLICY "Only admins can manage achievements" ON achievements FOR ALL USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- =====================================================
-- USER ACHIEVEMENTS Policies
-- =====================================================
CREATE POLICY "User achievements viewable by everyone" ON user_achievements FOR SELECT USING (true);
CREATE POLICY "System can update achievements" ON user_achievements FOR UPDATE USING (true);
CREATE POLICY "System can insert achievements" ON user_achievements FOR INSERT WITH CHECK (true);

-- =====================================================
-- STARTUP IDEAS Policies
-- =====================================================
CREATE POLICY "Startup ideas viewable by everyone" ON startup_ideas FOR SELECT USING (status = 'active');
CREATE POLICY "Authenticated users can create startup ideas" ON startup_ideas FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "Founders can update own ideas" ON startup_ideas FOR UPDATE USING (auth.uid() = founder_id);
CREATE POLICY "Founders can delete own ideas" ON startup_ideas FOR DELETE USING (auth.uid() = founder_id);

-- =====================================================
-- STARTUP TEAM MEMBERS Policies
-- =====================================================
CREATE POLICY "Team members viewable by everyone" ON startup_team_members FOR SELECT USING (true);
CREATE POLICY "Founders can manage team" ON startup_team_members FOR ALL USING (
  EXISTS (SELECT 1 FROM startup_ideas WHERE id = startup_team_members.startup_id AND founder_id = auth.uid())
);

-- =====================================================
-- JOBS Policies
-- =====================================================
CREATE POLICY "Jobs viewable by everyone" ON jobs FOR SELECT USING (is_active = true AND (expires_at IS NULL OR expires_at > NOW()));
CREATE POLICY "Authenticated users can post jobs" ON jobs FOR INSERT WITH CHECK (auth.uid() = posted_by);
CREATE POLICY "Posters can update own jobs" ON jobs FOR UPDATE USING (auth.uid() = posted_by);
CREATE POLICY "Posters can delete own jobs" ON jobs FOR DELETE USING (auth.uid() = posted_by);

-- =====================================================
-- JOB APPLICATIONS Policies
-- =====================================================
CREATE POLICY "Applicants can view own applications" ON job_applications FOR SELECT USING (auth.uid() = applicant_id);
CREATE POLICY "Job posters can view applications" ON job_applications FOR SELECT USING (
  EXISTS (SELECT 1 FROM jobs WHERE id = job_applications.job_id AND posted_by = auth.uid())
);
CREATE POLICY "Applicants can apply" ON job_applications FOR INSERT WITH CHECK (auth.uid() = applicant_id);
CREATE POLICY "Job posters can update applications" ON job_applications FOR UPDATE USING (
  EXISTS (SELECT 1 FROM jobs WHERE id = job_applications.job_id AND posted_by = auth.uid())
);

-- =====================================================
-- EVENTS Policies
-- =====================================================
CREATE POLICY "Events viewable by everyone" ON events FOR SELECT USING (status != 'cancelled');
CREATE POLICY "Authenticated users can create events" ON events FOR INSERT WITH CHECK (auth.uid() = organizer_id);
CREATE POLICY "Organizers can update own events" ON events FOR UPDATE USING (auth.uid() = organizer_id);
CREATE POLICY "Organizers can delete own events" ON events FOR DELETE USING (auth.uid() = organizer_id);

-- =====================================================
-- EVENT REGISTRATIONS Policies
-- =====================================================
CREATE POLICY "Users can view own registrations" ON event_registrations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Event organizers can view registrations" ON event_registrations FOR SELECT USING (
  EXISTS (SELECT 1 FROM events WHERE id = event_registrations.event_id AND organizer_id = auth.uid())
);
CREATE POLICY "Users can register for events" ON event_registrations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can cancel own registrations" ON event_registrations FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Organizers can check in attendees" ON event_registrations FOR UPDATE USING (
  EXISTS (SELECT 1 FROM events WHERE id = event_registrations.event_id AND organizer_id = auth.uid())
);

-- =====================================================
-- REPORTS Policies
-- =====================================================
CREATE POLICY "Users can view own reports" ON reports FOR SELECT USING (auth.uid() = reporter_id);
CREATE POLICY "Moderators can view all reports" ON reports FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND (is_admin = true OR is_moderator = true))
);
CREATE POLICY "Users can create reports" ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Moderators can update reports" ON reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND (is_admin = true OR is_moderator = true))
);

-- =====================================================
-- USER BLOCKS Policies
-- =====================================================
CREATE POLICY "Users can view own blocks" ON user_blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can block others" ON user_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can unblock" ON user_blocks FOR DELETE USING (auth.uid() = blocker_id);

-- =====================================================
-- USER MUTES Policies
-- =====================================================
CREATE POLICY "Users can view own mutes" ON user_mutes FOR SELECT USING (auth.uid() = muter_id);
CREATE POLICY "Users can mute others" ON user_mutes FOR INSERT WITH CHECK (auth.uid() = muter_id);
CREATE POLICY "Users can unmute" ON user_mutes FOR DELETE USING (auth.uid() = muter_id);

-- =====================================================
-- AUDIT LOGS Policies (Admin only)
-- =====================================================
CREATE POLICY "Only admins can view audit logs" ON audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
);
CREATE POLICY "System can create audit logs" ON audit_logs FOR INSERT WITH CHECK (true);

-- =====================================================
-- MODERATION LOGS Policies
-- =====================================================
CREATE POLICY "Moderators can view moderation logs" ON moderation_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND (is_admin = true OR is_moderator = true))
);
CREATE POLICY "Moderators can create logs" ON moderation_logs FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND (is_admin = true OR is_moderator = true))
);

-- =====================================================
-- POST VIEWS Policies
-- =====================================================
CREATE POLICY "Post views are automatically tracked" ON post_views FOR INSERT WITH CHECK (true);
CREATE POLICY "Post owners can view view stats" ON post_views FOR SELECT USING (
  EXISTS (SELECT 1 FROM posts WHERE id = post_views.post_id AND author_id = auth.uid())
);

-- =====================================================
-- PROFILE VIEWS Policies
-- =====================================================
CREATE POLICY "Profile views are automatically tracked" ON profile_views FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view own profile view stats" ON profile_views FOR SELECT USING (auth.uid() = profile_id);
