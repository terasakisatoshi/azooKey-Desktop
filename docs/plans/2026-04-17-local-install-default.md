# Local Install Default Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `./install.sh` default to a user-local install path that does not require an Xcode signing account.

**Architecture:** Replace the current archive-and-copy default path with a Debug `xcodebuild build` flow that disables code signing, copies the built app into `~/Library/Input Methods`, re-signs it ad hoc with the existing entitlements, registers it with Launch Services, and refreshes input-source agents. Keep the current archive/system install behavior behind an explicit opt-in flag so it remains available without being the default.

**Tech Stack:** Bash, `xcodebuild`, `codesign`, `PlistBuddy`, LaunchServices `lsregister`

---

### Task 1: Lock Default Local-Install Behavior With a Failing Test

**Files:**
- Modify: `tools/test_install.sh`

**Step 1: Write the failing test**

Extend the shell regression test so `./install.sh --ignore-lint` expects:
- `xcodebuild` to receive a Debug `build`
- `CODE_SIGNING_ALLOWED=NO`
- `CODE_SIGNING_REQUIRED=NO`
- install destination under `$HOME/Library/Input Methods`
- no reliance on archive provisioning flags for the default path

**Step 2: Run test to verify it fails**

Run: `bash tools/test_install.sh`
Expected: FAIL because `install.sh` still uses archive/system-install as the default path.

### Task 2: Implement Local-Install Default in `install.sh`

**Files:**
- Modify: `install.sh`

**Step 1: Add mode selection**

Introduce an explicit `--system-install` flag and make local-install the default mode.

**Step 2: Implement the local-install path**

Use `xcodebuild ... -configuration Debug ... build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`, copy the built app into `~/Library/Input Methods/azooKeyMac.app`, ad-hoc sign it with the existing entitlements, run `lsregister`, and refresh input-source agents.

**Step 3: Keep dry-run support meaningful**

Make `--dry-run` print the local-install commands in default mode and the archive/system commands only when `--system-install` is selected.

### Task 3: Verify the Change

**Files:**
- Modify: `tools/test_install.sh` if the implementation reveals missing coverage

**Step 1: Run the shell regression test**

Run: `bash tools/test_install.sh`
Expected: PASS

**Step 2: Run a targeted install dry-run**

Run: `./install.sh --ignore-lint --dry-run`
Expected: show the local-install flow, including `~/Library/Input Methods`, unsigned Debug build, ad-hoc signing, and registration commands.
