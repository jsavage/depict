#!/usr/bin/env python3
"""
Test harness for Depict WASM web application.
Automates browser testing including slow processing and lockup scenarios.

Requirements:
    pip install selenium webdriver-manager
    
Usage:
    python test_harness.py --url http://localhost:8080
    python test_harness.py --url http://localhost:8080 --test-slow
    python test_harness.py --url http://localhost:8080 --test-lockup
"""

import argparse
import time
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
from selenium.common.exceptions import TimeoutException, NoSuchElementException


class DepictTester:
    """Automated tester for the Depict web application."""
    
    def __init__(self, url, headless=False, network_latency=0, screenshot_dir=None):
        self.url = url
        self.network_latency = network_latency
        self.screenshot_dir = screenshot_dir
        if screenshot_dir:
            import os
            os.makedirs(screenshot_dir, exist_ok=True)
        self.setup_driver(headless)
        
    def setup_driver(self, headless):
        """Initialize the Chrome WebDriver."""
        chrome_options = Options()
        if headless:
            chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        # Enable browser logging
        chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
        
        service = Service(ChromeDriverManager().install())
        self.driver = webdriver.Chrome(service=service, options=chrome_options)
        self.driver.set_window_size(1920, 1080)
        self.wait = WebDriverWait(self.driver, 10)
        
        # Simulate network latency if requested (useful for testing remote deployments)
        if self.network_latency > 0:
            print(f"⚠ Simulating {self.network_latency}ms network latency")
            self.driver.execute_cdp_cmd('Network.enable', {})
            self.driver.execute_cdp_cmd('Network.emulateNetworkConditions', {
                'offline': False,
                'downloadThroughput': 500 * 1024 / 8,  # 500 kbps
                'uploadThroughput': 500 * 1024 / 8,
                'latency': self.network_latency
            })
        
    def load_page(self):
        """Load the Depict application."""
        print(f"Loading {self.url}...")
        
        # Check if URL is reachable first
        import urllib.request
        import urllib.error
        try:
            urllib.request.urlopen(self.url, timeout=10)
        except urllib.error.URLError as e:
            print(f"✗ Cannot reach {self.url}: {e}")
            return False
        except Exception as e:
            print(f"⚠ Warning: {e} (will try to load anyway)")
        
        self.driver.get(self.url)
        
        # Wait for page to load
        try:
            self.wait.until(
                EC.presence_of_element_located((By.TAG_NAME, "textarea"))
            )
            print("✓ Page loaded successfully")
            
            # Verify it's actually the Depict app by checking for specific elements
            try:
                self.driver.find_element(By.XPATH, "//details[contains(., 'Test Controls')]")
                print("✓ Verified: Depict application detected")
            except NoSuchElementException:
                print("⚠ Warning: This might not be the Depict application (Test Controls not found)")
            
            return True
        except TimeoutException:
            print("✗ Page failed to load (timeout waiting for textarea)")
            self.take_screenshot("page_load_failed")
            return False
    
    def get_textarea(self):
        """Get the main textarea element."""
        return self.driver.find_element(By.TAG_NAME, "textarea")
    
    def get_status_label(self):
        """Get the current status label text."""
        try:
            # The status label is the first div inside main_editor
            status_div = self.driver.find_element(By.CSS_SELECTOR, ".main_editor > div > div:first-child")
            return status_div.text
        except NoSuchElementException:
            return None
    
    def take_screenshot(self, name):
        """Save a screenshot to the output directory."""
        if self.screenshot_dir:
            import os
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"{name}_{timestamp}.png"
            filepath = os.path.join(self.screenshot_dir, filename)
            self.driver.save_screenshot(filepath)
            print(f"📸 Screenshot saved: {filepath}")
            return filepath
        return None
    
    def get_browser_logs(self):
        """Retrieve browser console logs."""
        return self.driver.get_log('browser')
    
    def enable_test_mode(self, mode="slow", delay_ms=2000):
        """Enable test mode controls.
        
        Args:
            mode: "slow" for slow processing, "lockup" for lockup simulation
            delay_ms: Delay in milliseconds for slow mode
        """
        try:
            # Open the test controls if not already open
            details = self.driver.find_element(By.XPATH, "//details[contains(., 'Test Controls')]")
            if not details.get_attribute("open"):
                summary = details.find_element(By.TAG_NAME, "summary")
                summary.click()
                time.sleep(0.2)
            
            if mode == "slow":
                # Find and click the slow processing checkbox
                checkbox = self.driver.find_element(
                    By.XPATH, 
                    "//input[@type='checkbox'][contains(following-sibling::text(), 'Simulate Slow Processing')]"
                )
                if not checkbox.is_selected():
                    checkbox.click()
                    print(f"✓ Enabled slow processing simulation ({delay_ms}ms)")
                
                # Adjust delay if needed
                slider = self.driver.find_element(By.XPATH, "//input[@type='range']")
                self.driver.execute_script(f"arguments[0].value = {delay_ms};", slider)
                self.driver.execute_script(
                    "arguments[0].dispatchEvent(new Event('input', { bubbles: true }));", 
                    slider
                )
                
            elif mode == "lockup":
                # Find and click the lockup checkbox
                checkbox = self.driver.find_element(
                    By.XPATH, 
                    "//input[@type='checkbox'][contains(following-sibling::text(), 'Simulate Lockup')]"
                )
                if not checkbox.is_selected():
                    checkbox.click()
                    print("✓ Enabled lockup simulation")
            
            return True
        except NoSuchElementException as e:
            print(f"✗ Failed to enable test mode: {e}")
            return False
    
    def disable_test_modes(self):
        """Disable all test modes."""
        try:
            details = self.driver.find_element(By.XPATH, "//details[contains(., 'Test Controls')]")
            if not details.get_attribute("open"):
                summary = details.find_element(By.TAG_NAME, "summary")
                summary.click()
                time.sleep(0.2)
            
            checkboxes = self.driver.find_elements(By.CSS_SELECTOR, "input[type='checkbox']")
            for checkbox in checkboxes:
                if checkbox.is_selected():
                    checkbox.click()
            
            print("✓ Disabled all test modes")
            return True
        except NoSuchElementException:
            return False
    
    def input_text(self, text):
        """Input text into the textarea."""
        textarea = self.get_textarea()
        textarea.clear()
        textarea.send_keys(text)
        print(f"✓ Input text: {text[:50]}...")
    
    def click_undo(self):
        """Click the undo button."""
        try:
            undo_button = self.driver.find_element(By.XPATH, "//button[contains(., 'Undo')]")
            undo_button.click()
            print("✓ Clicked undo")
            return True
        except NoSuchElementException:
            print("✗ Undo button not found")
            return False
    
    def wait_for_status(self, expected_status, timeout=10):
        """Wait for a specific status to appear.
        
        Args:
            expected_status: String to match in status label (e.g., "Processing", "Ready", "ERROR")
            timeout: Maximum time to wait in seconds
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.get_status_label()
            if status and expected_status.lower() in status.lower():
                print(f"✓ Status changed to: {status}")
                return True
            time.sleep(0.1)
        
        print(f"✗ Timeout waiting for status '{expected_status}'")
        return False
    
    def test_normal_operation(self):
        """Test normal diagram processing."""
        print("\n=== Testing Normal Operation ===")
        
        test_input = "A -> B: hello\nB -> C: world"
        self.input_text(test_input)
        
        if self.wait_for_status("Ready", timeout=5):
            print("✓ Normal processing completed successfully")
            return True
        else:
            print("✗ Normal processing failed")
            self.take_screenshot("normal_operation_failed")
            return False
    
    def test_slow_processing(self, delay_ms=3000):
        """Test slow processing simulation."""
        print(f"\n=== Testing Slow Processing ({delay_ms}ms delay) ===")
        
        self.enable_test_mode("slow", delay_ms)
        
        test_input = "X -> Y: test slow"
        self.input_text(test_input)
        
        # Should show "Processing..." for a while
        time.sleep(0.5)
        status = self.get_status_label()
        if "Processing" in status:
            print(f"✓ Status correctly shows: {status}")
        else:
            print(f"⚠ Expected 'Processing...', got: {status}")
        
        # Wait for completion
        if self.wait_for_status("Ready", timeout=delay_ms/1000 + 3):
            print("✓ Slow processing completed")
            self.disable_test_modes()
            return True
        else:
            print("✗ Slow processing did not complete")
            self.disable_test_modes()
            return False
    
    def test_lockup_recovery(self):
        """Test lockup simulation and recovery."""
        print("\n=== Testing Lockup and Recovery ===")
        
        # Get current text to restore later
        textarea = self.get_textarea()
        original_text = textarea.get_attribute("value")
        
        self.enable_test_mode("lockup")
        
        # This should trigger a timeout
        test_input = "P -> Q: trigger lockup"
        self.input_text(test_input)
        
        # Should timeout after 5 seconds
        if self.wait_for_status("TIMEOUT", timeout=7):
            print("✓ Timeout detected correctly")
            
            # Test undo functionality
            if self.click_undo():
                time.sleep(0.5)
                restored_text = self.get_textarea().get_attribute("value")
                if restored_text == original_text:
                    print("✓ Undo successfully restored previous state")
                    self.disable_test_modes()
                    return True
                else:
                    print(f"✗ Undo failed: expected '{original_text}', got '{restored_text}'")
            else:
                print("✗ Could not click undo button")
        else:
            print("✗ Timeout was not detected")
        
        self.disable_test_modes()
        return False
    
    def test_error_recovery(self):
        """Test error handling and recovery."""
        print("\n=== Testing Error Recovery ===")
        
        # Input something that might cause an error (malformed syntax)
        bad_input = "A -> -> B C: invalid syntax [[[]]"
        self.input_text(bad_input)
        
        time.sleep(1)
        status = self.get_status_label()
        
        if "ERROR" in status or "error" in status.lower():
            print(f"✓ Error detected: {status}")
            
            # Test recovery with undo
            if self.click_undo():
                if self.wait_for_status("Ready", timeout=2):
                    print("✓ Successfully recovered from error using undo")
                    return True
        else:
            print(f"⚠ Expected error status, got: {status}")
        
        return False
    
    def print_browser_logs(self):
        """Print recent browser console logs."""
        print("\n=== Recent Browser Logs ===")
        logs = self.get_browser_logs()
        for entry in logs[-10:]:  # Last 10 logs
            print(f"[{entry['level']}] {entry['message']}")
    
    def run_all_tests(self):
        """Run all test scenarios."""
        if not self.load_page():
            return False
        
        results = []
        
        # Run tests
        results.append(("Normal Operation", self.test_normal_operation()))
        results.append(("Slow Processing", self.test_slow_processing(2000)))
        results.append(("Lockup Recovery", self.test_lockup_recovery()))
        results.append(("Error Recovery", self.test_error_recovery()))
        
        # Print summary
        print("\n" + "="*50)
        print("TEST SUMMARY")
        print("="*50)
        for test_name, passed in results:
            status = "✓ PASSED" if passed else "✗ FAILED"
            print(f"{test_name:.<40} {status}")
        
        total = len(results)
        passed = sum(1 for _, p in results if p)
        print(f"\nTotal: {passed}/{total} tests passed")
        
        self.print_browser_logs()
        
        return all(p for _, p in results)
    
    def cleanup(self):
        """Close the browser."""
        print("\nCleaning up...")
        self.driver.quit()


def main():
    parser = argparse.ArgumentParser(
        description="Test harness for Depict WASM application",
        epilog="""
Examples:
  # Test local development server
  python test_harness.py --url http://localhost:8080
  
  # Test production deployment
  python test_harness.py --url https://depict.example.com
  
  # Run headless for CI/CD
  python test_harness.py --url https://depict.example.com --headless
  
  # Test with custom network conditions
  python test_harness.py --url https://depict.example.com --network-latency 1000
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--url",
        default="http://localhost:8080",
        help="URL of the Depict application (local or remote)"
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        help="Run browser in headless mode"
    )
    parser.add_argument(
        "--test-slow",
        action="store_true",
        help="Run only slow processing test"
    )
    parser.add_argument(
        "--test-lockup",
        action="store_true",
        help="Run only lockup test"
    )
    parser.add_argument(
        "--delay",
        type=int,
        default=2000,
        help="Delay for slow processing test (milliseconds)"
    )
    parser.add_argument(
        "--network-latency",
        type=int,
        default=0,
        help="Simulate network latency in milliseconds (for testing remote deployments)"
    )
    parser.add_argument(
        "--screenshot-on-failure",
        action="store_true",
        help="Save screenshots when tests fail"
    )
    parser.add_argument(
        "--output-dir",
        default="./test_results",
        help="Directory for test artifacts (screenshots, logs)"
    )
    
    args = parser.parse_args()
    
    # Create output directory if screenshots are enabled
    output_dir = args.output_dir if args.screenshot_on_failure else None
    
    tester = DepictTester(
        args.url, 
        args.headless, 
        args.network_latency,
        output_dir
    )
    
    try:
        if not tester.load_page():
            print("Failed to load page. Is the server running?")
            sys.exit(1)
        
        if args.test_slow:
            success = tester.test_slow_processing(args.delay)
        elif args.test_lockup:
            success = tester.test_lockup_recovery()
        else:
            success = tester.run_all_tests()
        
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        tester.cleanup()


if __name__ == "__main__":
    main()