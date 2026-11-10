# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Browser tab check during sessions: tabs on a blocked site or its subdomains are sent to a local "blocked" page in Safari, Chrome, Dia, Arc, Brave, Edge and Vivaldi. This covers browsers that skip `/etc/hosts` (secure DNS, open connections). Needs the macOS Automation permission once per browser.
- Focus on the dial: a running session lights up its stretch of time and dims the rest, the hand turns green and counts the minutes left, and finished sessions stay as thin arcs next to the clock face. The planner's side panel shows the countdown with pause and stop.
- Half-hour marks on the clock face.
- The website list is edited one site at a time with visible rows, and changes to it or to the app list apply to a running session immediately.
- Full-screen focus screen redrawn: the countdown sits in a clock-like ring that fills as the session passes, with the intention above and the next planned task below.
- The blocked page shows the session's intention and today's plan, with finished tasks struck through.
- Settings and the menu bar panel redrawn in the planner's paper-and-ink style.
- Week in review: hours per day, time per project and your commits, tracked automatically from file changes in the git repositories under a projects folder (default `~/Development`).
- Day planner redesign: an oversized half dial per part of the day, category rings (Focus, Meeting, Personal), a week strip and motion.

## [1.0.0] - Unreleased

### Added

- Menu bar focus timer with a live countdown in the menu bar.
- Session presets of 15, 25, 45, 60 and 90 minutes, plus a custom length.
- Optional breaks: 5 minutes after each session, 15 minutes after every fourth.
- Intention field shown during a session.
- Website blocking during sessions through a marked section of `/etc/hosts`, managed by a small root helper (`/Library/PrivilegedHelperTools/app.odak.block`) and a sudoers rule limited to that helper (`/etc/sudoers.d/app_odak`). Installed once with an admin password prompt.
- Blocking is cleared when a session ends or is stopped, when the app quits, and on the next launch after a crash.
- Hiding of chosen distracting apps during sessions.
- Full-screen focus screen during focus sessions that hides the Dock and the menu bar and shows the countdown and intention. Esc returns to the menu bar. Can be turned off in Settings.
- Day planner: a 12-hour dial with an AM/PM switch where tasks are created by dragging on the ring in 30-minute steps. A focus session can be started from the current task and runs until the task ends.
- Notifications with sound when a session or break ends.
- Stats with a 7-day chart and a daily streak.
- Launch at login.
- English and Turkish interface.

[Unreleased]: https://github.com/slymnyg/odak/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/slymnyg/odak/releases/tag/v1.0.0
