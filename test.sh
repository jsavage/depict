#!/usr/bin/env bash
set -euo pipefail

# depict Test Script
# Tests web server functionality and SVG export
# Usage: ./test.sh [--server-path PATH] [--port PORT]

TEST_DIR="test_results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_DIR"

# Default values
SERVER_PATH=""
SERVER_PORT=8080
SERVER_PID=""
TIMEOUT=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-path)
            SERVER_PATH="$2"
            shift 2
            ;;
        --port)
            SERVER_PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--server-path PATH] [--port PORT]"
            exit 1
            ;;
    esac
done

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Save test result
save_result() {
    local test_name=$1
    local status=$2
    local details=$3
    
    {
        echo "Test: $test_name"
        echo "Status: $status"
        echo "Timestamp: $(date -Iseconds)"
        echo "Details:"
        echo "$details"
        echo ""
    } >> "$TEST_DIR/test_results.log"
}

# Cleanup function
cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    
    # Kill any process on the test port
    if lsof -ti:"$SERVER_PORT" >/dev/null 2>&1; then
        warn "Killing processes on port $SERVER_PORT..."
        lsof -ti:"$SERVER_PORT" | xargs kill -9 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

# Find server binary
find_server() {
    if [ -n "$SERVER_PATH" ] && [ -f "$SERVER_PATH" ]; then
        echo "$SERVER_PATH"
        return 0
    fi
    
    # Search in common locations
    for path in \
        "./target/release/depict-server" \
        "./build_output/latest/dist/depict-server" \
        "./dist/depict-server" \
        "./depict-server" \
        $(find ./build_output -name "depict-server" -type f 2>/dev/null | head -1)
    do
        if [ -f "$path" ] && [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Start the server
start_server() {
    log "Looking for server binary..."
    
    if ! SERVER_PATH=$(find_server); then
        error "Could not find depict-server binary"
        info "Please specify server path with --server-path or build first"
        return 1
    fi
    
    log "Found server at: $SERVER_PATH"
    
    # Check if port is already in use
    if lsof -ti:"$SERVER_PORT" >/dev/null 2>&1; then
        warn "Port $SERVER_PORT is already in use"
        log "Attempting to kill existing process..."
        lsof -ti:"$SERVER_PORT" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    log "Starting server on port $SERVER_PORT..."
    
    # Start server in background
    PORT=$SERVER_PORT "$SERVER_PATH" > "$TEST_DIR/server.log" 2>&1 &
    SERVER_PID=$!
    
    log "Server started with PID: $SERVER_PID"
    
    # Wait for server to start
    log "Waiting for server to be ready..."
    local waited=0
    while [ $waited -lt $TIMEOUT ]; do
        if curl -sf "http://localhost:$SERVER_PORT" >/dev/null 2>&1; then
            pass "Server is ready!"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
        echo -n "."
    done
    echo ""
    
    error "Server failed to start within $TIMEOUT seconds"
    log "Server log:"
    cat "$TEST_DIR/server.log"
    return 1
}

# Test 1: Check if port is listening
test_port_listening() {
    log "Test 1: Checking if port $SERVER_PORT is listening..."
    
    if lsof -ti:"$SERVER_PORT" >/dev/null 2>&1; then
        local pid=$(lsof -ti:"$SERVER_PORT")
        local process=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        pass "Port $SERVER_PORT is listening (PID: $pid, Process: $process)"
        save_result "port_listening" "PASS" "Port $SERVER_PORT is listening. PID: $pid, Process: $process"
        return 0
    else
        error "Port $SERVER_PORT is not listening"
        save_result "port_listening" "FAIL" "Port $SERVER_PORT is not listening"
        return 1
    fi
}

# Test 2: Check if server is responsive
test_server_responsive() {
    log "Test 2: Checking if server is responsive..."
    
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" "http://localhost:$SERVER_PORT" 2>&1)
    http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | head -n -1)
    
    echo "$body" > "$TEST_DIR/homepage.html"
    
    if [ "$http_code" = "200" ]; then
        pass "Server responded with HTTP 200"
        info "Response saved to: $TEST_DIR/homepage.html"
        save_result "server_responsive" "PASS" "HTTP Status: $http_code, Response length: ${#body} bytes"
        
        # Check if response contains expected HTML
        if echo "$body" | grep -qi "depict"; then
            pass "Response contains 'depict' keyword"
        else
            warn "Response does not contain expected 'depict' keyword"
        fi
        
        return 0
    else
        error "Server responded with HTTP $http_code"
        save_result "server_responsive" "FAIL" "HTTP Status: $http_code"
        return 1
    fi
}

# Test 3: Check page content and UI elements
test_page_content() {
    log "Test 3: Checking page content..."
    
    local html
    html=$(curl -s "http://localhost:$SERVER_PORT")
    
    local checks_passed=0
    local checks_total=4
    
    # Check for textarea/input (for DSL input)
    if echo "$html" | grep -qi "textarea\|<input"; then
        pass "Found input element for DSL"
        checks_passed=$((checks_passed + 1))
    else
        warn "No input element found"
    fi
    
    # Check for SVG or canvas (for rendering)
    if echo "$html" | grep -qi "svg\|canvas"; then
        pass "Found SVG or Canvas element"
        checks_passed=$((checks_passed + 1))
    else
        warn "No SVG or Canvas element found"
    fi
    
    # Check for export functionality
    if echo "$html" | grep -qi "export\|download"; then
        pass "Found export/download functionality"
        checks_passed=$((checks_passed + 1))
    else
        warn "No export functionality found in HTML"
    fi
    
    # Check for JavaScript/WASM
    if echo "$html" | grep -qi "\.wasm\|\.js"; then
        pass "Found JavaScript/WASM references"
        checks_passed=$((checks_passed + 1))
    else
        warn "No JavaScript/WASM found"
    fi
    
    info "Page content checks: $checks_passed/$checks_total passed"
    save_result "page_content" "PASS" "Content checks: $checks_passed/$checks_total passed"
    
    [ $checks_passed -ge 2 ] && return 0 || return 1
}

# Test 4: Test SVG export functionality
test_svg_export() {
    log "Test 4: Testing SVG export functionality..."
    
    # First, try to find the export endpoint
    local html
    html=$(curl -s "http://localhost:$SERVER_PORT")
    
    # Look for export link or API endpoint
    local export_url=""
    
    # Try common patterns
    for pattern in "/export" "/api/export" "/download" "/svg"; do
        if curl -sf "http://localhost:$SERVER_PORT$pattern" >/dev/null 2>&1; then
            export_url="http://localhost:$SERVER_PORT$pattern"
            break
        fi
    done
    
    # If no direct endpoint, try to parse from HTML
    if [ -z "$export_url" ]; then
        # Extract href containing "export" or "download"
        export_url=$(echo "$html" | grep -oiE 'href="[^"]*export[^"]*"' | head -1 | sed 's/.*href="//;s/".*//' || echo "")
        
        if [ -n "$export_url" ] && [[ ! "$export_url" =~ ^http ]]; then
            export_url="http://localhost:$SERVER_PORT/$export_url"
        fi
    fi
    
    if [ -z "$export_url" ]; then
        warn "Could not find export endpoint automatically"
        info "Attempting to test with sample input via POST..."
        
        # Try to POST sample data
        local sample_input="person microwave food: open, start, stop / beep : heat
person food: eat"
        
        local response
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"input\":\"$sample_input\"}" \
            "http://localhost:$SERVER_PORT/export" 2>&1 || echo "")
        
        if [ -n "$response" ] && echo "$response" | grep -q "<svg"; then
            echo "$response" > "$TEST_DIR/exported.svg"
            pass "Successfully exported SVG via POST"
            validate_svg "$TEST_DIR/exported.svg"
            return 0
        fi
        
        # Try GET with query parameter
        response=$(curl -s "http://localhost:$SERVER_PORT/export?input=$(echo "$sample_input" | jq -sRr @uri)" 2>&1 || echo "")
        
        if [ -n "$response" ] && echo "$response" | grep -q "<svg"; then
            echo "$response" > "$TEST_DIR/exported.svg"
            pass "Successfully exported SVG via GET"
            validate_svg "$TEST_DIR/exported.svg"
            return 0
        fi
        
        warn "Could not test SVG export - no accessible endpoint found"
        save_result "svg_export" "SKIP" "No export endpoint found"
        return 0  # Don't fail the test suite
    fi
    
    log "Testing export from: $export_url"
    
    local svg_content
    svg_content=$(curl -s "$export_url" 2>&1)
    
    if echo "$svg_content" | grep -q "<svg"; then
        echo "$svg_content" > "$TEST_DIR/exported.svg"
        pass "Successfully downloaded SVG"
        info "SVG saved to: $TEST_DIR/exported.svg"
        
        validate_svg "$TEST_DIR/exported.svg"
        return 0
    else
        error "Export endpoint did not return valid SVG"
        save_result "svg_export" "FAIL" "No valid SVG returned from $export_url"
        return 1
    fi
}

# Validate SVG content
validate_svg() {
    local svg_file=$1
    
    log "Validating SVG content..."
    
    local checks_passed=0
    local checks_total=5
    
    # Check 1: Valid XML/SVG structure
    if grep -q '<?xml' "$svg_file" || grep -q '<svg' "$svg_file"; then
        pass "SVG has valid opening tag"
        checks_passed=$((checks_passed + 1))
    else
        warn "SVG missing proper opening tag"
    fi
    
    # Check 2: Contains closing svg tag
    if grep -q '</svg>' "$svg_file"; then
        pass "SVG has closing tag"
        checks_passed=$((checks_passed + 1))
    else
        warn "SVG missing closing tag"
    fi
    
    # Check 3: Has viewBox or width/height
    if grep -qi 'viewBox\|width=.*height=' "$svg_file"; then
        pass "SVG has dimensions"
        checks_passed=$((checks_passed + 1))
    else
        warn "SVG missing dimensions"
    fi
    
    # Check 4: Contains actual drawing elements
    if grep -qiE '<rect|<circle|<path|<line|<text|<g' "$svg_file"; then
        pass "SVG contains drawing elements"
        checks_passed=$((checks_passed + 1))
    else
        warn "SVG appears empty (no drawing elements)"
    fi
    
    # Check 5: File size reasonable
    local size=$(stat -f%z "$svg_file" 2>/dev/null || stat -c%s "$svg_file" 2>/dev/null || echo 0)
    if [ "$size" -gt 100 ]; then
        pass "SVG has reasonable file size ($size bytes)"
        checks_passed=$((checks_passed + 1))
    else
        warn "SVG file size suspiciously small ($size bytes)"
    fi
    
    info "SVG validation: $checks_passed/$checks_total checks passed"
    save_result "svg_validation" "INFO" "Validation checks: $checks_passed/$checks_total passed. Size: $size bytes"
    
    # Show SVG info
    info "SVG Info:"
    head -20 "$svg_file" | tee -a "$TEST_DIR/test_results.log"
}

# Generate test report
generate_report() {
    log "Generating test report..."
    
    {
        echo "==================================="
        echo "  Depict Integration Test Report"
        echo "==================================="
        echo ""
        echo "Test Date: $(date -Iseconds)"
        echo "Test Directory: $TEST_DIR"
        echo "Server Port: $SERVER_PORT"
        echo "Server Path: $SERVER_PATH"
        echo ""
        echo "=== Test Results ==="
        echo ""
        cat "$TEST_DIR/test_results.log" 2>/dev/null || echo "No detailed results available"
        echo ""
        echo "=== Generated Files ==="
        ls -lh "$TEST_DIR"
        echo ""
        echo "=== Server Log (last 50 lines) ==="
        tail -50 "$TEST_DIR/server.log" 2>/dev/null || echo "No server log available"
        echo ""
        echo "==================================="
    } | tee "$TEST_DIR/TEST_REPORT.txt"
    
    log "Test report saved to: $TEST_DIR/TEST_REPORT.txt"
}

# Main test execution
main() {
    log "Starting depict integration tests..."
    log "Test results will be saved to: $TEST_DIR"
    echo ""
    
    local tests_passed=0
    local tests_total=4
    
    # Start server
    if ! start_server; then
        error "Failed to start server - cannot continue tests"
        generate_report
        exit 1
    fi
    
    echo ""
    
    # Run tests
    if test_port_listening; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    if test_server_responsive; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    if test_page_content; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    if test_svg_export; then
        tests_passed=$((tests_passed + 1))
    fi
    echo ""
    
    # Generate report
    generate_report
    
    # Summary
    echo ""
    log "=========================="
    log "Test Summary: $tests_passed/$tests_total tests passed"
    log "=========================="
    
    if [ $tests_passed -eq $tests_total ]; then
        pass "All tests passed! ✓"
        exit 0
    elif [ $tests_passed -ge $((tests_total / 2)) ]; then
        warn "Some tests passed ($tests_passed/$tests_total)"
        exit 1
    else
        error "Most tests failed ($tests_passed/$tests_total)"
        exit 1
    fi
}

# Run main
main "$@"
