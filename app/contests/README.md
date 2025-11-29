# Contest Management

This directory contains contest definitions and their associated problems.

## Directory Structure

```
contests/
├── 1/
│   ├── contest.json          # Contest metadata
│   ├── 01.problem.json       # First problem
│   ├── 02.problem.json       # Second problem
│   └── 03.problem.json       # Third problem
├── 2/
│   ├── contest.json
│   ├── 01.problem.json
│   └── 02.problem.json
└── ...
```

## Contest JSON Format

Each contest directory must contain a `contest.json` file with the following structure:

```json
{
  "name": "Weekly Contest #1",
  "description": "Contest description here",
  "rules": "Contest rules and scoring information",
  "start_time": "2025-12-01T10:00:00Z",
  "end_time": "2025-12-01T12:00:00Z",
  "penalty_minutes": 20
}
```

### Required Fields

- **name** (string): Unique name for the contest
- **start_time** (ISO 8601 datetime): When the contest begins
- **end_time** (ISO 8601 datetime): When the contest ends
- **penalty_minutes** (integer): Minutes added per wrong submission (typically 10-20)

### Optional Fields

- **description** (string): General description of the contest
- **rules** (string): Detailed rules and scoring information

## Problem JSON Format

Problem files should be named `01.problem.json`, `02.problem.json`, etc. and follow this format:

```json
{
  "title": "Problem Title",
  "description": "Problem description with <b>HTML</b> formatting supported",
  "difficulty": "easy",
  "hidden": false,
  "memory_limit_kb": 2048,
  "time_limit_sec": 2,
  "tags": ["array", "hash-table"],
  "examples": [
    {
      "input": "sample input\n",
      "output": "expected output\n",
      "is_hidden": false
    }
  ],
  "constraints": [
    "1 <= n <= 10^4",
    "Constraint 2..."
  ]
}
```

### Required Fields

- **title** (string): Problem title (must be unique)
- **description** (string): Problem statement (HTML supported)
- **difficulty** (string): One of: `"easy"`, `"medium"`, `"hard"`
- **memory_limit_kb** (integer): Memory limit in kilobytes
- **time_limit_sec** (integer): Time limit in seconds
- **tags** (array): Problem category tags
- **examples** (array): Sample test cases
- **constraints** (array): Problem constraints

### Optional Fields

- **hidden** (boolean): Whether to hide from public view (default: true for contest problems)
  - **Important**: Contest problems with `hidden: true` will only appear on `/problems` after the contest ends
  - Contest problems with `hidden: false` are always visible on `/problems` (use sparingly)
  - During an active contest, participants can access problems regardless of this setting

## Rake Tasks

### Create Contests and Problems

Import all contests and their problems:

```bash
bundle exec rake contests:create
```

This will:
- Scan the `contests/` directory for subdirectories
- Create each contest from its `contest.json` file
- Create all problems (*.problem.json) associated with that contest
- Skip contests/problems that already exist (based on name/title)

### Force Update Contests and Problems

Update existing contests and problems:

```bash
bundle exec rake contests:create:force
```

This will:
- Update existing contests if they're found (by name)
- Update existing problems if they're found (by title)
- Create new contests/problems if they don't exist
- ⚠️ **Warning**: This will replace all examples, constraints, and tags

### Destroy All Contests

Remove all contests and their problems:

```bash
bundle exec rake contests:destroy
```

This will:
- Delete all contests from the database
- Delete all problems associated with contests
- Delete all examples, constraints, tags, and submissions for those problems
- ⚠️ **Warning**: This does NOT affect standalone problems (not in contests)

## Creating a New Contest

1. **Create a new directory** with a numeric name:
   ```bash
   mkdir contests/3
   ```

2. **Create contest.json** with contest metadata:
   ```bash
   nano contests/3/contest.json
   ```

3. **Add problem files** numbered sequentially:
   ```bash
   nano contests/3/01.problem.json
   nano contests/3/02.problem.json
   nano contests/3/03.problem.json
   ```

4. **Import the contest**:
   ```bash
   bundle exec rake contests:create
   ```

## Tips

- **Time Format**: Use ISO 8601 format for times: `"2025-12-01T10:00:00Z"`
- **Problem Ordering**: Problems are displayed in the order of their filenames (01, 02, 03...)
- **Problem Visibility**: 
  - Default is `hidden: true` for contest problems
  - Problems with `hidden: true` only appear on `/problems` after contest ends
  - Use `hidden: false` only if you want problems visible before contest starts
  - Participants can always access problems during active contests
- **HTML in Descriptions**: You can use HTML tags like `<b>`, `<code>`, `<h3>` in descriptions
- **Hidden Examples**: Mark some examples as `"is_hidden": true` for test cases not shown to users
- **Tags**: Common tags include: `array`, `string`, `math`, `dynamic-programming`, `tree`, `graph`, etc.

## Example

See `contests/1/` and `contests/2/` for complete examples of contest structures.
