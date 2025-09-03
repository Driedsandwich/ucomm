# Makefile for ucomm project
# Meeting minutes generation system

# Default values
DATE ?= $(shell date +%Y-%m-%d)
MODE ?= local
SUMMARIZER_MODE ?= local

# Directories
LOGS_DIR = logs
REPORTS_DIR = reports/minutes
SCRIPTS_DIR = scripts

# Default target
.PHONY: help
help:
	@echo "ucomm Makefile - Meeting Minutes Generation"
	@echo ""
	@echo "Targets:"
	@echo "  minutes          Generate meeting minutes for today (default)"
	@echo "  minutes-full     Generate minutes + summary"
	@echo "  clean-minutes    Clean generated minutes"
	@echo "  test-minutes     Run minutes system tests"
	@echo ""
	@echo "Variables:"
	@echo "  DATE=$(DATE)                 Target date (YYYY-MM-DD)"
	@echo "  MODE=$(MODE)                 Log mode (local, api, council)"
	@echo "  SUMMARIZER_MODE=$(SUMMARIZER_MODE)    Summarizer mode (local, api)"
	@echo ""
	@echo "Examples:"
	@echo "  make minutes DATE=2025-09-01 MODE=council"
	@echo "  make minutes-full SUMMARIZER_MODE=api"
	@echo "  OPENAI_API_KEY=sk-... make minutes-full SUMMARIZER_MODE=api"

# Main minutes generation target
.PHONY: minutes
minutes:
	@echo "Generating minutes for $(DATE)/$(MODE)..."
	@mkdir -p $(REPORTS_DIR)/$(DATE)
	$(SCRIPTS_DIR)/minutes.sh $(DATE) $(MODE)

# Full pipeline: minutes + summary
.PHONY: minutes-full
minutes-full: minutes
	@echo "Generating summary for $(DATE)/$(MODE) using $(SUMMARIZER_MODE)..."
	$(SCRIPTS_DIR)/summarizer.sh $(DATE) $(MODE) $(SUMMARIZER_MODE)

# Compose minutes (alternative entry point)
.PHONY: compose
compose:
	@if [ -f "$(SCRIPTS_DIR)/compose-minutes.sh" ]; then \
		$(SCRIPTS_DIR)/compose-minutes.sh $(DATE) $(MODE) $(SUMMARIZER_MODE); \
	else \
		$(MAKE) minutes-full DATE=$(DATE) MODE=$(MODE) SUMMARIZER_MODE=$(SUMMARIZER_MODE); \
	fi

# Clean generated minutes
.PHONY: clean-minutes
clean-minutes:
	@echo "Cleaning minutes for $(DATE)..."
	@rm -rf $(REPORTS_DIR)/$(DATE)
	@echo "Cleaned."

# Clean all generated minutes
.PHONY: clean-all-minutes
clean-all-minutes:
	@echo "Cleaning all generated minutes..."
	@rm -rf $(REPORTS_DIR)
	@echo "All minutes cleaned."

# Test the minutes system
.PHONY: test-minutes
test-minutes:
	@echo "Running minutes system tests..."
	@if [ -f "tests/test_minutes.sh" ]; then \
		tests/test_minutes.sh; \
	else \
		echo "Creating sample test data..."; \
		$(MAKE) create-sample-data; \
		echo "Running basic validation..."; \
		$(MAKE) validate-minutes-system; \
	fi

# Create sample test data
.PHONY: create-sample-data
create-sample-data:
	@echo "Creating sample data for testing..."
	@mkdir -p $(LOGS_DIR)/local/$(DATE)
	@echo -e "$(DATE) 09:00:00\tuser\tMeeting started" > $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo -e "$(DATE) 09:01:00\tadmin\t[#topic] Project status review" >> $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo -e "$(DATE) 09:02:00\tuser\tWe need to discuss the API integration issues" >> $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo -e "$(DATE) 09:03:00\tadmin\t決定: Use local summarizer as default" >> $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo -e "$(DATE) 09:04:00\tuser\tTODO: Update documentation by Friday" >> $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo -e "$(DATE) 09:05:00\tuser\tContact: john.doe@example.com for API keys" >> $(LOGS_DIR)/local/$(DATE)/session1.log
	@echo "Sample data created in $(LOGS_DIR)/local/$(DATE)/"

# Validate minutes system
.PHONY: validate-minutes-system
validate-minutes-system:
	@echo "Validating minutes system..."
	@echo "1. Testing mask.sh..."
	@echo "Test email: john@example.com" | $(SCRIPTS_DIR)/lib/mask.sh | grep -q "\[REDACTED:EMAIL\]" && echo "✓ Email masking works"
	@echo "2. Testing minutes.sh..."
	@$(MAKE) minutes DATE=$(DATE) MODE=local > /dev/null && echo "✓ Minutes generation works"
	@echo "3. Testing summarizer.sh (local mode)..."
	@$(SCRIPTS_DIR)/summarizer.sh $(DATE) local local > /dev/null && echo "✓ Local summarizer works"
	@echo "4. Checking output files..."
	@test -f $(REPORTS_DIR)/$(DATE)/local.md && echo "✓ Minutes file created"
	@test -f $(REPORTS_DIR)/$(DATE)/local.local.md && echo "✓ Summary file created"
	@echo "All validations passed!"

# Development utilities
.PHONY: watch-logs
watch-logs:
	@echo "Watching logs directory for changes..."
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o $(LOGS_DIR) | xargs -n1 -I{} $(MAKE) minutes; \
	elif command -v inotifywait >/dev/null 2>&1; then \
		while inotifywait -r -e modify $(LOGS_DIR); do $(MAKE) minutes; done; \
	else \
		echo "Install fswatch or inotify-tools for file watching"; \
		exit 1; \
	fi

# Show recent minutes
.PHONY: show-recent
show-recent:
	@echo "Recent minutes files:"
	@find $(REPORTS_DIR) -name "*.md" -type f -mtime -7 | head -10

# Backup minutes
.PHONY: backup-minutes
backup-minutes:
	@BACKUP_DIR="backups/minutes_$(shell date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$BACKUP_DIR"; \
	cp -r $(REPORTS_DIR)/* "$$BACKUP_DIR/" 2>/dev/null || true; \
	echo "Minutes backed up to $$BACKUP_DIR"

# Check system dependencies
.PHONY: check-deps
check-deps:
	@echo "Checking system dependencies..."
	@command -v awk >/dev/null && echo "✓ awk" || echo "✗ awk (required)"
	@command -v sed >/dev/null && echo "✓ sed" || echo "✗ sed (required)"  
	@command -v sort >/dev/null && echo "✓ sort" || echo "✗ sort (required)"
	@command -v curl >/dev/null && echo "✓ curl (for API mode)" || echo "- curl (optional, for API mode)"
	@test -x $(SCRIPTS_DIR)/lib/mask.sh && echo "✓ mask.sh" || echo "✗ mask.sh (missing)"
	@test -x $(SCRIPTS_DIR)/minutes.sh && echo "✓ minutes.sh" || echo "✗ minutes.sh (missing)"
	@test -x $(SCRIPTS_DIR)/summarizer.sh && echo "✓ summarizer.sh" || echo "✗ summarizer.sh (missing)"