#!/bin/bash
# create_package.sh - Create downloadable package

VERSION="1.0.0"
PACKAGE_NAME="correlation_tracker-${VERSION}"
PACKAGE_FILE="${PACKAGE_NAME}.tar.gz"

echo "Creating CorrelationTracker v${VERSION} package..."

# Create temporary directory
mkdir -p "/tmp/${PACKAGE_NAME}"
cd "/tmp/${PACKAGE_NAME}"

# Copy all gem files (you would run this from the gem directory)
# cp -r /path/to/gem/* .

# Create archive
cd /tmp
tar -czf "${PACKAGE_FILE}" "${PACKAGE_NAME}"

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${PACKAGE_FILE}" | cut -d' ' -f1)

echo ""
echo "✓ Package created: ${PACKAGE_FILE}"
echo "✓ SHA256: ${CHECKSUM}"
echo ""
echo "Package contents:"
tar -tzf "${PACKAGE_FILE}" | head -20
echo "... (showing first 20 files)"
echo ""
echo "Total files: $(tar -tzf ${PACKAGE_FILE} | wc -l)"
echo ""
echo "To extract:"
echo "  tar -xzf ${PACKAGE_FILE}"
echo ""
echo "To install:"
echo "  cd ${PACKAGE_NAME}"
echo "  gem build correlation_tracker.gemspec"
echo "  gem install correlation_tracker-${VERSION}.gem"
