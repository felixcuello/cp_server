#!/bin/bash

# Script to create a new contest with template files
# Usage: ./create_contest.sh <contest_number> [number_of_problems]
#
# Example:
#   ./create_contest.sh 3          # Creates contest 3 with 3 problems (default)
#   ./create_contest.sh 4 5        # Creates contest 4 with 5 problems

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if contest number is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Contest number is required${NC}"
    echo ""
    echo "Usage: $0 <contest_number> [number_of_problems]"
    echo ""
    echo "Examples:"
    echo "  $0 3          # Creates contest 3 with 3 problems (default)"
    echo "  $0 4 5        # Creates contest 4 with 5 problems"
    exit 1
fi

CONTEST_NUM=$1
NUM_PROBLEMS=${2:-3}  # Default to 3 problems if not specified

CONTEST_DIR="app/contests/$CONTEST_NUM"
TEMPLATE_DIR="app/contests"

# Check if contest directory already exists
if [ -d "$CONTEST_DIR" ]; then
    echo -e "${RED}Error: Contest $CONTEST_NUM already exists at $CONTEST_DIR${NC}"
    exit 1
fi

# Check if templates exist
if [ ! -f "$TEMPLATE_DIR/contest.template.json" ]; then
    echo -e "${RED}Error: Template file not found: $TEMPLATE_DIR/contest.template.json${NC}"
    exit 1
fi

if [ ! -f "$TEMPLATE_DIR/problem.template.json" ]; then
    echo -e "${RED}Error: Template file not found: $TEMPLATE_DIR/problem.template.json${NC}"
    exit 1
fi

echo -e "${GREEN}Creating contest $CONTEST_NUM with $NUM_PROBLEMS problems...${NC}"
echo ""

# Create contest directory
mkdir -p "$CONTEST_DIR"

# Copy contest.json template
cp "$TEMPLATE_DIR/contest.template.json" "$CONTEST_DIR/contest.json"
echo -e "${GREEN}✓${NC} Created $CONTEST_DIR/contest.json"

# Create problem files
for i in $(seq 1 $NUM_PROBLEMS); do
    # Format number with leading zero (01, 02, etc.)
    PROBLEM_NUM=$(printf "%02d" $i)
    PROBLEM_FILE="$CONTEST_DIR/${PROBLEM_NUM}.problem.json"
    
    cp "$TEMPLATE_DIR/problem.template.json" "$PROBLEM_FILE"
    echo -e "${GREEN}✓${NC} Created $PROBLEM_FILE"
done

echo ""
echo -e "${GREEN}Success!${NC} Contest $CONTEST_NUM created at $CONTEST_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit $CONTEST_DIR/contest.json with contest details"
echo "  2. Edit each problem file (${CONTEST_DIR}/01.problem.json, etc.)"
echo "  3. Run 'make contests-create' to import into database"
echo ""
echo -e "${YELLOW}Tip:${NC} Look at app/contests/1/ and app/contests/2/ for examples"
echo ""
