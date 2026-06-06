# Database Migrations

This directory contains database migration scripts for schema updates and data transformations.

## Migration Format

Migration files should follow the naming convention: `YYYYMMDD_HHMMSS_description.sql`

Example: `20240101_120000_add_user_notifications.sql`

## Running Migrations

To apply all pending migrations:
```bash
mysql -u chatties_user -p chatties_db < migration_file.sql
```

## Current Schema Version

- Version: 1.0.0
- Last Updated: 2024-01-01
- Status: Active
