.PHONY: prepare restore-models restore-llama pack-models pack-llama analyze test build-apk build-ios clean-models clean-llama help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

prepare: ## One-click setup (restore models + llama.cpp + pub get)
	./prepare.sh

restore-models: ## Restore models from split archive
	./restore_models.sh

restore-llama: ## Restore llama.cpp from split archive
	./restore_llama_cpp.sh

pack-models: ## Re-pack models into split archive
	./pack_models.sh

pack-llama: ## Re-pack llama.cpp into split archive
	./pack_llama_cpp.sh

analyze: ## Run flutter analyze (auto-restores if needed)
	./prepare.sh --skip-download
	flutter analyze

test: ## Run flutter test (auto-restores if needed)
	./prepare.sh --skip-download
	flutter test -r compact

build-apk: ## Build Android debug APK (auto-restores if needed)
	./prepare.sh --skip-download
	flutter build apk --debug

build-ios: ## Build iOS release (no codesign) (auto-restores if needed)
	./prepare.sh --skip-download
	flutter build ios --release --no-codesign

clean-models: ## Remove restored models directory
	rm -rf assets/models

clean-llama: ## Remove restored llama.cpp directory
	rm -rf third_party/llama.cpp

clean: clean-models clean-llama ## Remove all restored directories
