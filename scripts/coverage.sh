#!/bin/bash

# Coverage measurement script with threshold gate
# Usage: ./scripts/coverage.sh [threshold]
# Default threshold: 70%

THRESHOLD=${1:-70}

echo "📊 Running Flutter Tests with Coverage..."
flutter test --coverage

if [ $? -ne 0 ]; then
    echo "❌ Tests failed"
    exit 1
fi

echo ""
echo "📈 Generating Coverage Report..."

# Check if lcov is available
if ! command -v genhtml &> /dev/null; then
    echo "⚠️  lcov not found. Installing..."
    # For macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install lcov
    # For Ubuntu/Debian
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y lcov
    else
        echo "❌ Please install lcov manually"
        exit 1
    fi
fi

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

echo ""
echo "✅ Coverage report generated: coverage/html/index.html"
echo ""

# Extract line coverage percentage
LINE_COVERAGE=$(grep "lines\." coverage/lcov.info | tail -1 | cut -d':' -f2 | cut -d',' -f1)

# Calculate percentage
if [ -z "$LINE_COVERAGE" ]; then
    echo "❌ Could not extract coverage data"
    exit 1
fi

COVERAGE_PERCENT=$(echo "scale=2; $LINE_COVERAGE * 100" | bc)

echo "📊 Line Coverage: ${COVERAGE_PERCENT}%"
echo "🎯 Threshold: ${THRESHOLD}%"
echo ""

# Check if coverage meets threshold
if (( $(echo "$COVERAGE_PERCENT < $THRESHOLD" | bc -l) )); then
    echo "❌ Coverage ${COVERAGE_PERCENT}% is below threshold ${THRESHOLD}%"
    exit 1
else
    echo "✅ Coverage ${COVERAGE_PERCENT}% meets threshold ${THRESHOLD}%"
    exit 0
fi
