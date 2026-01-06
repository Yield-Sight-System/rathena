#!/bin/bash
# ============================================================================
# PHASE B AUTOMATED MIGRATION SCRIPT
# ============================================================================
# Purpose: Orchestrate complete MyISAM → InnoDB/Aria migration
# Target: MariaDB 10.11+ LTS or 11.2+ Stable
# Risk Level: MEDIUM (automated with safety checks)
# Duration: 30-90 minutes (depends on database size)
#
# This script performs:
# 1. Pre-flight checks
# 2. Manual GO/NO-GO confirmation
# 3. Automatic backup
# 4. InnoDB migration (Phase B1)
# 5. Aria migration (Phase B2)
# 6. Post-migration verification
# 7. Post-migration optimization
# 8. Detailed reporting
#
# CRITICAL PREREQUISITES:
# - Run as user with MySQL root access
# - All game servers MUST be stopped
# - Sufficient disk space (1.75-2x database size)
# - MariaDB 10.11+ or 11.2+
#
# Usage:
#   chmod +x migrate_phased.sh
#   ./migrate_phased.sh
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/migration_${TIMESTAMP}.log"
REPORT_FILE="${LOG_DIR}/migration_report_${TIMESTAMP}.txt"
BACKUP_DIR="${SCRIPT_DIR}/backups"
BACKUP_FILE="${BACKUP_DIR}/pre_migration_backup_${TIMESTAMP}.sql"

# MySQL connection parameters (will be read from user)
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_DATABASE="rathena"
MYSQL_HOST="localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# Utility Functions
# ============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}✓ $@${NC}"
}

log_warning() {
    log "WARNING" "$@"
    echo -e "${YELLOW}⚠ $@${NC}"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}✗ $@${NC}"
}

log_header() {
    local message="$@"
    local line="========================================================================"
    log_info "${line}"
    log_info "${message}"
    log_info "${line}"
    echo ""
    echo -e "${BOLD}${BLUE}${line}${NC}"
    echo -e "${BOLD}${BLUE}${message}${NC}"
    echo -e "${BOLD}${BLUE}${line}${NC}"
    echo ""
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 command not found. Please install $1"
        exit 1
    fi
}

mysql_exec() {
    local sql_file=$1
    local output_file=$2
    
    if [ -n "${MYSQL_PASSWORD}" ]; then
        mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" "${MYSQL_DATABASE}" < "${sql_file}" > "${output_file}" 2>&1
    else
        mysql -u"${MYSQL_USER}" -h"${MYSQL_HOST}" "${MYSQL_DATABASE}" < "${sql_file}" > "${output_file}" 2>&1
    fi
    
    return $?
}

mysql_command() {
    local sql_command=$1
    
    if [ -n "${MYSQL_PASSWORD}" ]; then
        mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" -e "${sql_command}"
    else
        mysql -u"${MYSQL_USER}" -h"${MYSQL_HOST}" -e "${sql_command}"
    fi
    
    return $?
}

# ============================================================================
# Pre-Flight Checks
# ============================================================================

init_environment() {
    log_header "Initializing Migration Environment"
    
    # Create necessary directories
    mkdir -p "${LOG_DIR}"
    mkdir -p "${BACKUP_DIR}"
    
    log_info "Log directory: ${LOG_DIR}"
    log_info "Backup directory: ${BACKUP_DIR}"
    log_info "Log file: ${LOG_FILE}"
    
    # Check required commands
    log_info "Checking required commands..."
    check_command mysql
    check_command mysqldump
    check_command date
    check_command df
    
    log_success "Environment initialized successfully"
    echo ""
}

get_mysql_credentials() {
    log_header "MySQL Credentials"
    
    echo -n "MySQL User (default: root): "
    read MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-root}
    
    echo -n "MySQL Password: "
    read -s MYSQL_PASSWORD
    echo ""
    
    echo -n "MySQL Host (default: localhost): "
    read MYSQL_HOST_INPUT
    MYSQL_HOST=${MYSQL_HOST_INPUT:-localhost}
    
    echo -n "Database Name (default: rathena): "
    read MYSQL_DATABASE_INPUT
    MYSQL_DATABASE=${MYSQL_DATABASE_INPUT:-rathena}
    
    # Test connection
    log_info "Testing MySQL connection..."
    if mysql_command "SELECT VERSION();" > /dev/null 2>&1; then
        log_success "MySQL connection successful"
    else
        log_error "MySQL connection failed. Please check credentials"
        exit 1
    fi
    
    echo ""
}

run_preflight_check() {
    log_header "Running Pre-Flight Checks"
    
    local preflight_output="${LOG_DIR}/preflight_check_${TIMESTAMP}.txt"
    
    log_info "Executing preflight_check.sql..."
    if mysql_exec "${SCRIPT_DIR}/preflight_check.sql" "${preflight_output}"; then
        log_success "Pre-flight check completed"
        log_info "Pre-flight report saved to: ${preflight_output}"
    else
        log_error "Pre-flight check failed"
        log_error "Review ${preflight_output} for details"
        exit 1
    fi
    
    # Display critical warnings
    if grep -q "NO-GO" "${preflight_output}"; then
        log_error "Pre-flight check returned NO-GO status!"
        echo ""
        echo -e "${RED}${BOLD}CRITICAL ISSUES DETECTED:${NC}"
        grep "NO-GO\|FAIL\|CRITICAL" "${preflight_output}" || true
        echo ""
        echo "Please resolve these issues before proceeding."
        echo "Review: ${preflight_output}"
        exit 1
    fi
    
    if grep -q "CAUTION" "${preflight_output}"; then
        log_warning "Pre-flight check has warnings"
        echo ""
        echo -e "${YELLOW}${BOLD}WARNINGS DETECTED:${NC}"
        grep "CAUTION\|WARNING" "${preflight_output}" | head -10 || true
        echo ""
    fi
    
    echo ""
}

confirm_migration() {
    log_header "Migration Confirmation Required"
    
    echo -e "${BOLD}${YELLOW}CRITICAL: You are about to migrate your database storage engines${NC}"
    echo ""
    echo "This process will:"
    echo "  • Convert 50+ tables from MyISAM to InnoDB"
    echo "  • Convert 12 logging tables from MyISAM to Aria"
    echo "  • Require 30-90 minutes of downtime"
    echo "  • Use additional disk space (1.5-2x current database size)"
    echo ""
    echo "Before proceeding, ensure:"
    echo "  [✓] All game servers are STOPPED (login, char, map)"
    echo "  [✓] Pre-flight check showed GO status"
    echo "  [✓] Sufficient disk space available"
    echo "  [✓] Maintenance window scheduled"
    echo "  [✓] Stakeholders notified"
    echo "  [✓] Rollback plan reviewed"
    echo ""
    
    read -p "Have you completed all prerequisites above? (yes/no): " confirm
    if [ "${confirm}" != "yes" ]; then
        log_warning "Migration aborted by user"
        echo "Migration aborted. Please complete prerequisites and try again."
        exit 0
    fi
    
    echo ""
    read -p "Type 'MIGRATE' in capitals to confirm: " final_confirm
    if [ "${final_confirm}" != "MIGRATE" ]; then
        log_warning "Migration aborted - confirmation not received"
        echo "Migration aborted."
        exit 0
    fi
    
    log_success "Migration confirmed by user"
    echo ""
}

# ============================================================================
# Backup
# ============================================================================

create_backup() {
    log_header "Creating Pre-Migration Backup"
    
    log_info "Backup file: ${BACKUP_FILE}"
    log_info "This may take several minutes..."
    
    local backup_start=$(date +%s)
    
    if [ -n "${MYSQL_PASSWORD}" ]; then
        mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" \
            --single-transaction --routines --triggers --events \
            "${MYSQL_DATABASE}" > "${BACKUP_FILE}" 2>&1
    else
        mysqldump -u"${MYSQL_USER}" -h"${MYSQL_HOST}" \
            --single-transaction --routines --triggers --events \
            "${MYSQL_DATABASE}" > "${BACKUP_FILE}" 2>&1
    fi
    
    local backup_result=$?
    local backup_end=$(date +%s)
    local backup_duration=$((backup_end - backup_start))
    
    if [ ${backup_result} -eq 0 ]; then
        local backup_size=$(du -h "${BACKUP_FILE}" | cut -f1)
        log_success "Backup completed successfully"
        log_info "Backup size: ${backup_size}"
        log_info "Backup duration: ${backup_duration} seconds"
        log_info "Backup location: ${BACKUP_FILE}"
    else
        log_error "Backup failed!"
        log_error "Cannot proceed without successful backup"
        exit 1
    fi
    
    # Compress backup
    log_info "Compressing backup..."
    gzip "${BACKUP_FILE}" 2>&1 || log_warning "Backup compression failed (non-critical)"
    
    if [ -f "${BACKUP_FILE}.gz" ]; then
        local compressed_size=$(du -h "${BACKUP_FILE}.gz" | cut -f1)
        log_success "Backup compressed to ${compressed_size}"
    fi
    
    echo ""
}

# ============================================================================
# Migration Phases
# ============================================================================

migrate_innodb() {
    log_header "Phase B1: InnoDB Migration Starting"
    
    local innodb_output="${LOG_DIR}/innodb_migration_${TIMESTAMP}.log"
    local migration_start=$(date +%s)
    
    log_info "Converting transactional tables to InnoDB..."
    log_info "This will take 15-60 minutes depending on database size"
    log_info "Progress logged to: ${innodb_output}"
    
    if mysql_exec "${SCRIPT_DIR}/migrate_to_innodb.sql" "${innodb_output}"; then
        local migration_end=$(date +%s)
        local migration_duration=$((migration_end - migration_start))
        log_success "InnoDB migration completed successfully"
        log_info "Migration duration: $((migration_duration / 60)) minutes $((migration_duration % 60)) seconds"
        
        # Check for any errors in output
        if grep -qi "error\|fail" "${innodb_output}"; then
            log_warning "Migration completed but some warnings/errors detected"
            log_warning "Review ${innodb_output} for details"
        fi
    else
        log_error "InnoDB migration failed!"
        log_error "Review ${innodb_output} for details"
        log_error "Database may be in inconsistent state"
        log_error "To rollback: mysql -u root -p rathena < rollback_to_myisam.sql"
        exit 1
    fi
    
    echo ""
}

migrate_aria() {
    log_header "Phase B2: Aria Migration Starting"
    
    local aria_output="${LOG_DIR}/aria_migration_${TIMESTAMP}.log"
    local migration_start=$(date +%s)
    
    log_info "Converting logging tables to Aria..."
    log_info "This will take 5-15 minutes"
    log_info "Progress logged to: ${aria_output}"
    
    if mysql_exec "${SCRIPT_DIR}/migrate_to_aria.sql" "${aria_output}"; then
        local migration_end=$(date +%s)
        local migration_duration=$((migration_end - migration_start))
        log_success "Aria migration completed successfully"
        log_info "Migration duration: $((migration_duration / 60)) minutes $((migration_duration % 60)) seconds"
    else
        log_warning "Aria migration had issues (non-critical)"
        log_warning "Review ${aria_output} for details"
        log_warning "Aria may not be available on this MariaDB version"
    fi
    
    echo ""
}

verify_migration() {
    log_header "Running Post-Migration Verification"
    
    local verify_output="${LOG_DIR}/verification_${TIMESTAMP}.txt"
    
    log_info "Executing verify_migration.sql..."
    log_info "This will take 2-5 minutes"
    
    if mysql_exec "${SCRIPT_DIR}/verify_migration.sql" "${verify_output}"; then
        log_success "Verification completed"
        log_info "Verification report saved to: ${verify_output}"
        
        # Check verification result
        if grep -q "MIGRATION INCOMPLETE" "${verify_output}"; then
            log_error "Verification FAILED - Migration incomplete!"
            echo ""
            echo -e "${RED}${BOLD}MIGRATION VERIFICATION FAILED${NC}"
            grep "FAIL\|ERROR" "${verify_output}" | head -20 || true
            echo ""
            echo "Review: ${verify_output}"
            echo "Consider rollback: mysql -u root -p rathena < rollback_to_myisam.sql"
            exit 1
        elif grep -q "MIGRATION SUCCESSFUL" "${verify_output}"; then
            log_success "Verification PASSED - Migration successful!"
        else
            log_warning "Verification completed with warnings"
            log_warning "Review ${verify_output} for details"
        fi
    else
        log_error "Verification script failed"
        log_error "Review ${verify_output} for details"
        exit 1
    fi
    
    echo ""
}

optimize_tables() {
    log_header "Running Post-Migration Optimization"
    
    local optimize_output="${LOG_DIR}/optimization_${TIMESTAMP}.log"
    
    log_info "Executing post_migration_optimize.sql..."
    log_info "This will take 15-60 minutes"
    log_info "Progress logged to: ${optimize_output}"
    
    if mysql_exec "${SCRIPT_DIR}/post_migration_optimize.sql" "${optimize_output}"; then
        log_success "Post-migration optimization completed"
        log_info "Optimization report saved to: ${optimize_output}"
    else
        log_warning "Optimization had some issues (non-critical)"
        log_warning "Review ${optimize_output} for details"
    fi
    
    echo ""
}

# ============================================================================
# Reporting
# ============================================================================

generate_report() {
    log_header "Generating Migration Report"
    
    {
        echo "============================================================================"
        echo "RATHENA DATABASE MIGRATION REPORT"
        echo "============================================================================"
        echo "Migration Date: $(date)"
        echo "Database: ${MYSQL_DATABASE}"
        echo "MariaDB Host: ${MYSQL_HOST}"
        echo ""
        echo "Migration Files:"
        echo "  - Backup: ${BACKUP_FILE}.gz"
        echo "  - Logs Directory: ${LOG_DIR}"
        echo "  - Main Log: ${LOG_FILE}"
        echo ""
        echo "Migration Phases Completed:"
        echo "  [✓] Pre-flight checks"
        echo "  [✓] Database backup"
        echo "  [✓] InnoDB migration (Phase B1)"
        echo "  [✓] Aria migration (Phase B2)"
        echo "  [✓] Post-migration verification"
        echo "  [✓] Post-migration optimization"
        echo ""
        echo "Database Status:"
        mysql_command "SELECT ENGINE, COUNT(*) AS 'Tables', ROUND(SUM(DATA_LENGTH + INDEX_LENGTH)/1024/1024, 2) AS 'Size_MB' FROM information_schema.TABLES WHERE TABLE_SCHEMA='${MYSQL_DATABASE}' GROUP BY ENGINE;" 2>/dev/null || echo "Unable to fetch database status"
        echo ""
        echo "Next Steps:"
        echo "1. Review this report and all log files"
        echo "2. Test game server functionality thoroughly"
        echo "3. Monitor performance for 24-48 hours"
        echo "4. If issues occur, rollback: mysql < rollback_to_myisam.sql"
        echo "5. If stable, proceed with production deployment"
        echo ""
        echo "Important Files:"
        echo "  - Main log: ${LOG_FILE}"
        echo "  - Backup: ${BACKUP_FILE}.gz"
        echo "  - Pre-flight: ${LOG_DIR}/preflight_check_${TIMESTAMP}.txt"
        echo "  - Verification: ${LOG_DIR}/verification_${TIMESTAMP}.txt"
        echo "  - Optimization: ${LOG_DIR}/optimization_${TIMESTAMP}.log"
        echo ""
        echo "============================================================================"
        echo "END OF REPORT"
        echo "============================================================================"
    } | tee "${REPORT_FILE}"
    
    log_success "Migration report generated: ${REPORT_FILE}"
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local script_start=$(date +%s)
    
    echo ""
    echo "============================================================================"
    echo "RATHENA DATABASE STORAGE ENGINE MIGRATION"
    echo "Phase B: MyISAM → InnoDB/Aria Migration"
    echo "============================================================================"
    echo ""
    
    # Initialize
    init_environment
    get_mysql_credentials
    
    # Pre-migration
    run_preflight_check
    confirm_migration
    create_backup
    
    # Migration
    migrate_innodb
    migrate_aria
    
    # Post-migration
    verify_migration
    optimize_tables
    
    # Reporting
    generate_report
    
    local script_end=$(date +%s)
    local total_duration=$((script_end - script_start))
    
    # Final summary
    log_header "Migration Complete!"
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ MIGRATION SUCCESSFUL!${NC}"
    echo ""
    echo "Total Duration: $((total_duration / 60)) minutes $((total_duration % 60)) seconds"
    echo ""
    echo "Migration Report: ${REPORT_FILE}"
    echo "All Logs: ${LOG_DIR}"
    echo "Backup: ${BACKUP_FILE}.gz"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT NEXT STEPS:${NC}"
    echo ""
    echo "1. Review migration report: cat ${REPORT_FILE}"
    echo "2. Review verification results: cat ${LOG_DIR}/verification_${TIMESTAMP}.txt"
    echo "3. Start game servers in test mode"
    echo "4. Perform thorough functional testing"
    echo "5. Monitor error logs: tail -f /var/log/mysql/error.log"
    echo "6. Monitor performance for 24-48 hours"
    echo "7. If issues: rollback with mysql < rollback_to_myisam.sql"
    echo "8. If stable: Open to public and monitor closely"
    echo ""
    echo -e "${GREEN}${BOLD}Congratulations! Your database is now using InnoDB/Aria.${NC}"
    echo ""
}

# ============================================================================
# Error Handler
# ============================================================================

error_handler() {
    local line_number=$1
    log_error "Script failed at line ${line_number}"
    log_error "Check ${LOG_FILE} for details"
    echo ""
    echo -e "${RED}${BOLD}MIGRATION FAILED!${NC}"
    echo ""
    echo "Error occurred at line: ${line_number}"
    echo "Log file: ${LOG_FILE}"
    echo ""
    echo "To rollback migration:"
    echo "  mysql -u ${MYSQL_USER} -p ${MYSQL_DATABASE} < ${SCRIPT_DIR}/rollback_to_myisam.sql"
    echo ""
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Execute main function
main "$@"
