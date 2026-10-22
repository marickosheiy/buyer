-- Run once on the standalone mobile database when enabling direct publishing.
-- Email verification is still required; suspended/rejected shops stay restricted.
UPDATE sellers s JOIN users u ON u.id=s.user_id
SET s.status='active',s.updated_at=UTC_TIMESTAMP()
WHERE s.status='pending' AND u.email_verified_at IS NOT NULL AND u.is_suspended=0;

UPDATE products p JOIN sellers s ON s.id=p.seller_id JOIN users u ON u.id=s.user_id
SET p.moderation_status='active',p.updated_at=UTC_TIMESTAMP()
WHERE p.moderation_status='pending' AND p.deleted_at IS NULL
AND s.status IN ('active','approved') AND u.email_verified_at IS NOT NULL AND u.is_suspended=0;
