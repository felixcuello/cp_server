# Contest System - Quick Start Guide

This document explains the new contest-based directory structure for organizing problems.

## Overview

Contests are now stored in the `app/contests/` directory with the following structure:

```
app/contests/
├── 1/                          # Contest ID
│   ├── contest.json            # Contest metadata
│   ├── 01.problem.json         # Problem 1
│   ├── 02.problem.json         # Problem 2
│   └── 03.problem.json         # Problem 3
├── 2/                          # Another contest
│   ├── contest.json
│   ├── 01.problem.json
│   └── 02.problem.json
└── README.md                   # Full documentation
```

## Quick Commands

### Import New Contests

```bash
make contests-create
```

This scans `app/contests/` and imports all contests and their problems. Skips existing contests.

### Update Existing Contests

```bash
make contests-update
```

Updates existing contests and problems. Creates new ones if they don't exist.

⚠️ **Warning**: Replaces all examples, constraints, and tags for problems.

### Delete All Contests

```bash
make contests-destroy
```

Removes all contests and their associated problems from the database.

## Creating a New Contest

### Step 1: Create Directory

```bash
mkdir app/contests/3
```

### Step 2: Create contest.json

Create `app/contests/3/contest.json`:

```json
{
  "name": "My Contest #3",
  "description": "Contest description",
  "rules": "Contest rules and scoring",
  "start_time": "2026-02-01T10:00:00Z",
  "end_time": "2026-02-01T12:00:00Z",
  "penalty_minutes": 20
}
```

### Step 3: Add Problems

Create problem files like `app/contests/3/01.problem.json`:

```json
{
  "title": "Problem Title",
  "description": "Problem statement here",
  "difficulty": "easy",
  "hidden": false,
  "memory_limit_kb": 2048,
  "time_limit_sec": 2,
  "tags": ["array", "hash-table"],
  "examples": [
    {
      "input": "input here\n",
      "output": "output here\n",
      "is_hidden": false
    }
  ],
  "constraints": [
    "1 <= n <= 10^4"
  ]
}
```

### Step 4: Import

```bash
make contests-create
```

## Key Features

### Contest Metadata

- **name**: Unique identifier for the contest
- **start_time/end_time**: ISO 8601 format (e.g., `2025-12-01T10:00:00Z`)
- **penalty_minutes**: Time penalty per wrong submission (typically 10-20)
- **description**: General contest information
- **rules**: Detailed rules and scoring system

### Problem Features

- **Difficulty levels**: `easy`, `medium`, `hard`
- **Tags**: Categorize by algorithm type (e.g., `array`, `dynamic-programming`)
- **Examples**: Mix of visible and hidden test cases
- **Constraints**: Problem limitations
- **HTML support**: Use HTML tags in descriptions for formatting

### Contest States

Contests automatically track their state:

- **Upcoming**: Before `start_time`
- **Active**: Between `start_time` and `end_time`
- **Ended**: After `end_time`

### Access Control

- **Admins**: Can always view and manage all contests
- **Users**: Must join a contest to participate; can only access active or ended contests they've joined

## Examples

Two example contests are included:

1. **Contest 1**: Beginner-friendly (3 easy-medium problems)
   - Two Sum
   - Palindrome Number
   - Longest Common Prefix

2. **Contest 2**: Advanced algorithms (2 hard problems)
   - Binary Tree Maximum Path Sum
   - Median of Two Sorted Arrays

Explore `app/contests/1/` and `app/contests/2/` to see the complete structure.

## Workflow

### Development Workflow

1. **Create contests in advance**: Set up contests with future start dates
2. **Test locally**: Use `make contests-create` to import and test
3. **Update as needed**: Use `make contests-update` to make changes
4. **Schedule contests**: Set appropriate `start_time` and `end_time`

### Production Deployment

When deploying to production:

```bash
# In your deployment script
bundle exec rake contests:create
```

This ensures all defined contests are imported during deployment.

## Migration from Old System

The old `app/problems/` directory still works with the existing rake tasks:

```bash
bundle exec rake problems:create        # Old system
bundle exec rake contests:create        # New system
```

Both systems can coexist:
- Standalone problems in `app/problems/`
- Contest-organized problems in `app/contests/`

## Further Documentation

See `app/contests/README.md` for complete documentation including:
- Full JSON schemas
- All available options
- Tips and best practices
- Detailed rake task explanations

## Support

For questions or issues with the contest system, refer to:
- `app/contests/README.md` - Complete documentation
- `app/lib/tasks/create_contests_task.rake` - Implementation details
- Example contests in `app/contests/1/` and `app/contests/2/`
