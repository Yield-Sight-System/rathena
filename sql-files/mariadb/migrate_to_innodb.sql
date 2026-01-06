-- ============================================================================
-- PHASE B1: MyISAM to InnoDB Migration Script
-- ============================================================================
-- Purpose: Convert critical transactional tables from MyISAM to InnoDB
-- Target: MariaDB 10.11+ LTS or 11.2+ Stable
-- Risk Level: MEDIUM (requires backup and testing)
-- Duration: 15-60 minutes (depends on database size)
--
-- CRITICAL PREREQUISITES:
-- 1. Run preflight_check.sql and verify GO status
-- 2. Create full backup: mysqldump --single-transaction rathena > backup.sql
-- 3. Stop ALL game servers (login, char, map)
-- 4. Verify no active connections
-- 5. Ensure 1.75-2x database size free disk space
--
-- Usage:
--   mysql -u root -p rathena < migrate_to_innodb.sql > migration_innodb.log 2>&1
--   Review log for errors before proceeding
-- ============================================================================

SELECT '============================================================================' AS '';
SELECT 'PHASE B1: InnoDB Migration Starting' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Migration Start Time';
SELECT DATABASE() AS 'Target Database';
SELECT USER() AS 'Executing User';
SELECT VERSION() AS 'MariaDB Version';
SELECT '' AS '';

-- Disable foreign key checks for migration
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;

SELECT 'Foreign key checks and unique checks temporarily disabled for migration' AS 'Info';
SELECT '' AS '';

-- ============================================================================
-- PHASE 1: CRITICAL TIER - Character and Account Data
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 1: CRITICAL TIER - Character and Account Data' AS '';
SELECT 'Priority: HIGHEST - Data loss prevention' AS '';
SELECT '============================================================================' AS '';

-- Character table (MOST CRITICAL)
SELECT CONCAT('Converting: char - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'char';

ALTER TABLE `char` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ char table converted to InnoDB' AS 'Status';
SELECT '' AS '';

-- Login table (CRITICAL - Authentication)
SELECT CONCAT('Converting: login - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login';

ALTER TABLE `login` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ login table converted to InnoDB' AS 'Status';
SELECT '' AS '';

-- Character registry tables
SELECT CONCAT('Converting: char_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `char_reg_num` ENGINE=InnoDB;
SELECT '✓ char_reg_num converted' AS 'Status';

SELECT CONCAT('Converting: char_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `char_reg_str` ENGINE=InnoDB;
SELECT '✓ char_reg_str converted' AS 'Status';

-- Account registry tables
SELECT CONCAT('Converting: acc_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `acc_reg_num` ENGINE=InnoDB;
SELECT '✓ acc_reg_num converted' AS 'Status';

SELECT CONCAT('Converting: acc_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `acc_reg_str` ENGINE=InnoDB;
SELECT '✓ acc_reg_str converted' AS 'Status';

-- Global account registry
SELECT CONCAT('Converting: global_acc_reg_num - ', NOW()) AS 'Progress';
ALTER TABLE `global_acc_reg_num` ENGINE=InnoDB;
SELECT '✓ global_acc_reg_num converted' AS 'Status';

SELECT CONCAT('Converting: global_acc_reg_str - ', NOW()) AS 'Progress';
ALTER TABLE `global_acc_reg_str` ENGINE=InnoDB;
SELECT '✓ global_acc_reg_str converted' AS 'Status';

SELECT 'PHASE 1 COMPLETE: Character and Account Data' AS '';
SELECT NOW() AS 'Phase 1 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 2: CRITICAL TIER - Inventory and Storage Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 2: CRITICAL TIER - Inventory and Storage Systems' AS '';
SELECT 'Priority: HIGHEST - Prevent item duplication/loss' AS '';
SELECT '============================================================================' AS '';

-- Player inventory (HIGH VOLUME - Use DYNAMIC row format)
SELECT CONCAT('Converting: inventory - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'inventory';

ALTER TABLE `inventory` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ inventory table converted to InnoDB' AS 'Status';
SELECT '' AS '';

-- Storage systems
SELECT CONCAT('Converting: storage - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'storage';

ALTER TABLE `storage` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ storage converted' AS 'Status';
SELECT '' AS '';

SELECT CONCAT('Converting: cart_inventory - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cart_inventory';

ALTER TABLE `cart_inventory` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ cart_inventory converted' AS 'Status';
SELECT '' AS '';

SELECT CONCAT('Converting: guild_storage - ', NOW()) AS 'Progress';
SELECT CONCAT('Current size: ', ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2), ' MB, Rows: ', TABLE_ROWS)
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'guild_storage';

ALTER TABLE `guild_storage` ENGINE=InnoDB ROW_FORMAT=DYNAMIC;
SELECT '✓ guild_storage converted' AS 'Status';
SELECT '' AS '';

SELECT 'PHASE 2 COMPLETE: Inventory and Storage Systems' AS '';
SELECT NOW() AS 'Phase 2 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 3: HIGH PRIORITY - Guild System
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 3: HIGH PRIORITY - Guild System' AS '';
SELECT 'Priority: HIGH - Multi-user transactions' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: guild - ', NOW()) AS 'Progress';
ALTER TABLE `guild` ENGINE=InnoDB;
SELECT '✓ guild converted' AS 'Status';

SELECT CONCAT('Converting: guild_member - ', NOW()) AS 'Progress';
ALTER TABLE `guild_member` ENGINE=InnoDB;
SELECT '✓ guild_member converted' AS 'Status';

SELECT CONCAT('Converting: guild_position - ', NOW()) AS 'Progress';
ALTER TABLE `guild_position` ENGINE=InnoDB;
SELECT '✓ guild_position converted' AS 'Status';

SELECT CONCAT('Converting: guild_alliance - ', NOW()) AS 'Progress';
ALTER TABLE `guild_alliance` ENGINE=InnoDB;
SELECT '✓ guild_alliance converted' AS 'Status';

SELECT CONCAT('Converting: guild_castle - ', NOW()) AS 'Progress';
ALTER TABLE `guild_castle` ENGINE=InnoDB;
SELECT '✓ guild_castle converted' AS 'Status';

SELECT CONCAT('Converting: guild_skill - ', NOW()) AS 'Progress';
ALTER TABLE `guild_skill` ENGINE=InnoDB;
SELECT '✓ guild_skill converted' AS 'Status';

SELECT CONCAT('Converting: guild_expulsion - ', NOW()) AS 'Progress';
ALTER TABLE `guild_expulsion` ENGINE=InnoDB;
SELECT '✓ guild_expulsion converted' AS 'Status';

SELECT CONCAT('Converting: guild_storage_log - ', NOW()) AS 'Progress';
ALTER TABLE `guild_storage_log` ENGINE=InnoDB;
SELECT '✓ guild_storage_log converted' AS 'Status';

SELECT 'PHASE 3 COMPLETE: Guild System' AS '';
SELECT NOW() AS 'Phase 3 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 4: HIGH PRIORITY - Party and Social Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 4: HIGH PRIORITY - Party and Social Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: party - ', NOW()) AS 'Progress';
ALTER TABLE `party` ENGINE=InnoDB;
SELECT '✓ party converted' AS 'Status';

SELECT CONCAT('Converting: party_bookings - ', NOW()) AS 'Progress';
ALTER TABLE `party_bookings` ENGINE=InnoDB;
SELECT '✓ party_bookings converted' AS 'Status';

SELECT CONCAT('Converting: friends - ', NOW()) AS 'Progress';
ALTER TABLE `friends` ENGINE=InnoDB;
SELECT '✓ friends converted' AS 'Status';

SELECT 'PHASE 4 COMPLETE: Party and Social Systems' AS '';
SELECT NOW() AS 'Phase 4 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 5: HIGH PRIORITY - Communication Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 5: HIGH PRIORITY - Communication Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: mail - ', NOW()) AS 'Progress';
ALTER TABLE `mail` ENGINE=InnoDB;
SELECT '✓ mail converted' AS 'Status';

SELECT CONCAT('Converting: mail_attachments - ', NOW()) AS 'Progress';
ALTER TABLE `mail_attachments` ENGINE=InnoDB;
SELECT '✓ mail_attachments converted' AS 'Status';

SELECT 'PHASE 5 COMPLETE: Communication Systems' AS '';
SELECT NOW() AS 'Phase 5 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 6: HIGH PRIORITY - Economy and Trading Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 6: HIGH PRIORITY - Economy and Trading Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: auction - ', NOW()) AS 'Progress';
ALTER TABLE `auction` ENGINE=InnoDB;
SELECT '✓ auction converted' AS 'Status';

SELECT CONCAT('Converting: vendings - ', NOW()) AS 'Progress';
ALTER TABLE `vendings` ENGINE=InnoDB;
SELECT '✓ vendings converted' AS 'Status';

SELECT CONCAT('Converting: vending_items - ', NOW()) AS 'Progress';
ALTER TABLE `vending_items` ENGINE=InnoDB;
SELECT '✓ vending_items converted' AS 'Status';

SELECT CONCAT('Converting: buyingstores - ', NOW()) AS 'Progress';
ALTER TABLE `buyingstores` ENGINE=InnoDB;
SELECT '✓ buyingstores converted' AS 'Status';

SELECT CONCAT('Converting: buyingstore_items - ', NOW()) AS 'Progress';
ALTER TABLE `buyingstore_items` ENGINE=InnoDB;
SELECT '✓ buyingstore_items converted' AS 'Status';

SELECT CONCAT('Converting: barter - ', NOW()) AS 'Progress';
ALTER TABLE `barter` ENGINE=InnoDB;
SELECT '✓ barter converted' AS 'Status';

SELECT CONCAT('Converting: market - ', NOW()) AS 'Progress';
ALTER TABLE `market` ENGINE=InnoDB;
SELECT '✓ market converted' AS 'Status';

SELECT CONCAT('Converting: sales - ', NOW()) AS 'Progress';
ALTER TABLE `sales` ENGINE=InnoDB;
SELECT '✓ sales converted' AS 'Status';

SELECT 'PHASE 6 COMPLETE: Economy and Trading Systems' AS '';
SELECT NOW() AS 'Phase 6 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 7: MEDIUM PRIORITY - Game Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 7: MEDIUM PRIORITY - Game Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: skill - ', NOW()) AS 'Progress';
ALTER TABLE `skill` ENGINE=InnoDB;
SELECT '✓ skill converted' AS 'Status';

SELECT CONCAT('Converting: skillcooldown - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown` ENGINE=InnoDB;
SELECT '✓ skillcooldown converted' AS 'Status';

SELECT CONCAT('Converting: quest - ', NOW()) AS 'Progress';
ALTER TABLE `quest` ENGINE=InnoDB;
SELECT '✓ quest converted' AS 'Status';

SELECT CONCAT('Converting: achievement - ', NOW()) AS 'Progress';
ALTER TABLE `achievement` ENGINE=InnoDB;
SELECT '✓ achievement converted' AS 'Status';

SELECT CONCAT('Converting: hotkey - ', NOW()) AS 'Progress';
ALTER TABLE `hotkey` ENGINE=InnoDB;
SELECT '✓ hotkey converted' AS 'Status';

SELECT CONCAT('Converting: sc_data - ', NOW()) AS 'Progress';
ALTER TABLE `sc_data` ENGINE=InnoDB;
SELECT '✓ sc_data converted' AS 'Status';

SELECT CONCAT('Converting: memo - ', NOW()) AS 'Progress';
ALTER TABLE `memo` ENGINE=InnoDB;
SELECT '✓ memo converted' AS 'Status';

SELECT 'PHASE 7 COMPLETE: Game Systems' AS '';
SELECT NOW() AS 'Phase 7 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 8: MEDIUM PRIORITY - Companion Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 8: MEDIUM PRIORITY - Companion Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: pet - ', NOW()) AS 'Progress';
ALTER TABLE `pet` ENGINE=InnoDB;
SELECT '✓ pet converted' AS 'Status';

SELECT CONCAT('Converting: homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `homunculus` ENGINE=InnoDB;
SELECT '✓ homunculus converted' AS 'Status';

SELECT CONCAT('Converting: skill_homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `skill_homunculus` ENGINE=InnoDB;
SELECT '✓ skill_homunculus converted' AS 'Status';

SELECT CONCAT('Converting: skillcooldown_homunculus - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown_homunculus` ENGINE=InnoDB;
SELECT '✓ skillcooldown_homunculus converted' AS 'Status';

SELECT CONCAT('Converting: mercenary - ', NOW()) AS 'Progress';
ALTER TABLE `mercenary` ENGINE=InnoDB;
SELECT '✓ mercenary converted' AS 'Status';

SELECT CONCAT('Converting: mercenary_owner - ', NOW()) AS 'Progress';
ALTER TABLE `mercenary_owner` ENGINE=InnoDB;
SELECT '✓ mercenary_owner converted' AS 'Status';

SELECT CONCAT('Converting: skillcooldown_mercenary - ', NOW()) AS 'Progress';
ALTER TABLE `skillcooldown_mercenary` ENGINE=InnoDB;
SELECT '✓ skillcooldown_mercenary converted' AS 'Status';

SELECT CONCAT('Converting: elemental - ', NOW()) AS 'Progress';
ALTER TABLE `elemental` ENGINE=InnoDB;
SELECT '✓ elemental converted' AS 'Status';

SELECT 'PHASE 8 COMPLETE: Companion Systems' AS '';
SELECT NOW() AS 'Phase 8 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 9: MEDIUM PRIORITY - Clan System
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 9: MEDIUM PRIORITY - Clan System' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: clan - ', NOW()) AS 'Progress';
ALTER TABLE `clan` ENGINE=InnoDB;
SELECT '✓ clan converted' AS 'Status';

SELECT CONCAT('Converting: clan_alliance - ', NOW()) AS 'Progress';
ALTER TABLE `clan_alliance` ENGINE=InnoDB;
SELECT '✓ clan_alliance converted' AS 'Status';

SELECT 'PHASE 9 COMPLETE: Clan System' AS '';
SELECT NOW() AS 'Phase 9 Completion Time';
SELECT '' AS '';

-- ============================================================================
-- PHASE 10: MEDIUM PRIORITY - Other Critical Systems
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'PHASE 10: MEDIUM PRIORITY - Other Critical Systems' AS '';
SELECT '============================================================================' AS '';

SELECT CONCAT('Converting: mapreg - ', NOW()) AS 'Progress';
ALTER TABLE `mapreg` ENGINE=InnoDB;
SELECT '✓ mapreg converted' AS 'Status';

SELECT CONCAT('Converting: ipbanlist - ', NOW()) AS 'Progress';
ALTER TABLE `ipbanlist` ENGINE=InnoDB;
SELECT '✓ ipbanlist converted' AS 'Status';

SELECT CONCAT('Converting: db_roulette - ', NOW()) AS 'Progress';
ALTER TABLE `db_roulette` ENGINE=InnoDB;
SELECT '✓ db_roulette converted' AS 'Status';

SELECT 'PHASE 10 COMPLETE: Other Critical Systems' AS '';
SELECT NOW() AS 'Phase 10 Completion Time';
SELECT '' AS '';

-- Re-enable checks
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;

SELECT 'Foreign key checks and unique checks re-enabled' AS 'Info';
SELECT '' AS '';

-- ============================================================================
-- POST-MIGRATION VERIFICATION
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'POST-MIGRATION VERIFICATION' AS '';
SELECT '============================================================================' AS '';

-- Verify engine conversions
SELECT 'Verifying converted tables...' AS 'Status';
SELECT '' AS '';

SELECT 
    TABLE_NAME,
    ENGINE,
    TABLE_ROWS,
    ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS 'Size_MB',
    CREATE_TIME,
    UPDATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'char', 'login', 'char_reg_num', 'char_reg_str', 
    'acc_reg_num', 'acc_reg_str', 'global_acc_reg_num', 'global_acc_reg_str',
    'inventory', 'storage', 'cart_inventory', 'guild_storage',
    'guild', 'guild_member', 'guild_position', 'guild_alliance', 
    'guild_castle', 'guild_skill', 'guild_expulsion', 'guild_storage_log',
    'party', 'party_bookings', 'friends',
    'mail', 'mail_attachments',
    'auction', 'vendings', 'vending_items', 'buyingstores', 'buyingstore_items',
    'barter', 'market', 'sales',
    'skill', 'skillcooldown', 'quest', 'achievement', 'hotkey', 'sc_data', 'memo',
    'pet', 'homunculus', 'skill_homunculus', 'skillcooldown_homunculus',
    'mercenary', 'mercenary_owner', 'skillcooldown_mercenary', 'elemental',
    'clan', 'clan_alliance',
    'mapreg', 'ipbanlist', 'db_roulette'
  )
ORDER BY TABLE_NAME;

SELECT '' AS '';

-- Count conversions
SELECT 
    COUNT(*) AS 'Total Tables Converted',
    SUM(TABLE_ROWS) AS 'Total Rows',
    ROUND(SUM(DATA_LENGTH + INDEX_LENGTH)/1024/1024/1024, 2) AS 'Total Size GB'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE = 'InnoDB'
  AND TABLE_NAME IN (
    'char', 'login', 'char_reg_num', 'char_reg_str', 
    'acc_reg_num', 'acc_reg_str', 'global_acc_reg_num', 'global_acc_reg_str',
    'inventory', 'storage', 'cart_inventory', 'guild_storage',
    'guild', 'guild_member', 'guild_position', 'guild_alliance', 
    'guild_castle', 'guild_skill', 'guild_expulsion', 'guild_storage_log',
    'party', 'party_bookings', 'friends',
    'mail', 'mail_attachments',
    'auction', 'vendings', 'vending_items', 'buyingstores', 'buyingstore_items',
    'barter', 'market', 'sales',
    'skill', 'skillcooldown', 'quest', 'achievement', 'hotkey', 'sc_data', 'memo',
    'pet', 'homunculus', 'skill_homunculus', 'skillcooldown_homunculus',
    'mercenary', 'mercenary_owner', 'skillcooldown_mercenary', 'elemental',
    'clan', 'clan_alliance',
    'mapreg', 'ipbanlist', 'db_roulette'
  );

-- Check for any failed conversions
SELECT 'Checking for failed conversions...' AS 'Status';
SELECT TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND ENGINE != 'InnoDB'
  AND TABLE_NAME IN (
    'char', 'login', 'char_reg_num', 'char_reg_str', 
    'acc_reg_num', 'acc_reg_str', 'global_acc_reg_num', 'global_acc_reg_str',
    'inventory', 'storage', 'cart_inventory', 'guild_storage',
    'guild', 'guild_member', 'guild_position', 'guild_alliance', 
    'guild_castle', 'guild_skill', 'guild_expulsion', 'guild_storage_log',
    'party', 'party_bookings', 'friends',
    'mail', 'mail_attachments',
    'auction', 'vendings', 'vending_items', 'buyingstores', 'buyingstore_items',
    'barter', 'market', 'sales',
    'skill', 'skillcooldown', 'quest', 'achievement', 'hotkey', 'sc_data', 'memo',
    'pet', 'homunculus', 'skill_homunculus', 'skillcooldown_homunculus',
    'mercenary', 'mercenary_owner', 'skillcooldown_mercenary', 'elemental',
    'clan', 'clan_alliance',
    'mapreg', 'ipbanlist', 'db_roulette'
  );

SELECT '' AS '';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
SELECT '============================================================================' AS '';
SELECT 'InnoDB MIGRATION COMPLETE!' AS '';
SELECT '============================================================================' AS '';
SELECT NOW() AS 'Migration End Time';
SELECT '' AS '';

SELECT 'NEXT STEPS:' AS '';
SELECT '1. Run verify_migration.sql for comprehensive verification' AS '';
SELECT '2. Run post_migration_optimize.sql for InnoDB optimization' AS '';
SELECT '3. Review error log: tail -f /var/log/mysql/error.log' AS '';
SELECT '4. Test database integrity with game server startup (test mode)' AS '';
SELECT '5. Monitor performance for 1-2 hours before opening to public' AS '';
SELECT '6. If issues occur, use rollback_to_myisam.sql' AS '';
SELECT '' AS '';

SELECT 'CRITICAL: Do NOT restart game servers until:' AS '';
SELECT '  - verify_migration.sql shows all checks passed' AS '';
SELECT '  - post_migration_optimize.sql completed' AS '';
SELECT '  - No errors in MariaDB error log' AS '';
SELECT '' AS '';

SELECT '============================================================================' AS '';
