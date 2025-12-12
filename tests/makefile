# Makefile
test-local:
	uv run python test_harness_v8.py --url http://localhost:8080

test-prod:
	uv run python test_harness_v8.py --url https://hconsult.helioho.st --headless

test-slow:
	uv run python test_harness_v8.py --url http://localhost:8080 --test-slow
