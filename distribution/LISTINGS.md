# StayAwake: listing drafts and later plans

Nothing here has been posted. Every item needs you to submit it under your name.
Facts used: v1.4.0 (heat and low-battery cutoffs for lid-closed mode, 10% default, thermal at 'serious'; not yet released), $4.99 once after a 7-day trial, macOS 13+, Apple silicon + Intel, signed and notarized, MIT source.
Always say you built it. Demo video = animation with a simulated upload, not a screen recording. Carry My Workstation = beta.

Links
- Site: https://pratiknayakprojects-dev.github.io/StayAwake/
- Guide: https://pratiknayakprojects-dev.github.io/StayAwake/keep-mac-awake-lid-closed.html
- Download: https://github.com/pratiknayakprojects-dev/StayAwake/releases/latest/download/StayAwake.dmg
- Buy: https://pratikprojects.gumroad.com/l/efsecq
- Source: https://github.com/pratiknayakprojects-dev/StayAwake

---------------------------------------------------------------------

## 1. AlternativeTo

Name: StayAwake
Tagline (short): Menu bar app that keeps your Mac awake, even with the lid closed
Platform: Mac. License: Paid (free trial). Price: $4.99 one-time, 7-day trial. Open source: yes (MIT source).
Alternative to: Amphetamine, KeepingYouAwake, Caffeinate

Description:
StayAwake is a small menu bar app for macOS that keeps your Mac awake. Keep Awake uses a normal power assertion. Keep Awake When Lid Closed also prevents sleep when you shut the lid, with no external display, using a small helper you approve once. An auto-stop timer (10 minutes to 3 hours) turns it off for you. Lid-closed mode also stops itself if macOS reports serious heat or the battery falls below a level you choose (10% by default), and if the app quits, crashes or is force-quit, the helper restores normal sleep.

Universal binary (Apple silicon and Intel), macOS 13 or later, signed and notarized. 7-day free trial, then $4.99 once, no subscription. Source is MIT on GitHub. I'm the developer.

Also includes Carry My Workstation (beta, not widely tested): keeps the Mac awake for an hour and tries to rejoin your iPhone's hotspot.

Features to tick: menu bar, timer, lid-closed mode, open source, no subscription.
Tags: keep awake, caffeinate, prevent sleep, menu bar, clamshell.

How it differs (use in "why it's an alternative" if asked):
- vs Caffeinate / KeepingYouAwake: those hold power assertions, which a lid close overrides. StayAwake also has a lid-closed mode.
- vs Amphetamine: Amphetamine is free and has many more features and triggers. StayAwake is simpler, and paid. Say this plainly.

---------------------------------------------------------------------

## 2. MacUpdate

Title: StayAwake
Version: 1.4.0. Category: Utilities. Price: $4.99 (7-day trial). macOS 13+.
Short description (111 chars):
Menu bar app that keeps your Mac awake, even with the lid closed. Timer included. 7-day trial, then $4.99 once.

Full description:
StayAwake keeps your Mac awake from the menu bar. Choose Keep Awake to stop idle sleep, or Keep Awake When Lid Closed to keep working with the lid shut, no external display needed. Pick an auto-stop timer from 10 minutes to 3 hours and the menu bar icon drains like a cup as time runs out.

Lid-closed mode uses a small root helper you approve once. It stops itself on serious heat or low battery. If StayAwake quits, crashes or is killed, the helper restores normal sleep.

Universal (Apple silicon and Intel), macOS 13 or later, signed and notarized by Apple. 7-day free trial, then a one-time $4.99 license through Gumroad. MIT-licensed source on GitHub. Built by me, Pratik Nayak.

What's new (1.4.0): Lid-Closed Safety. Closed-lid mode now stops itself, and normal sleep returns, if macOS reports serious heat or the battery falls below a level you choose (10% by default), with a notification saying why.
Support: pratiknayakprojects+stayawake@gmail.com

---------------------------------------------------------------------

## 3. Uneed

Name: StayAwake
Tagline (60 chars max): Keep your Mac awake with the lid closed
Description:
A menu bar app for macOS. One click keeps your Mac awake, even with the lid shut, and a timer switches it off for you. Safe by design: it stops itself if the Mac runs hot or the battery gets low, and if the app quits or crashes, normal sleep is restored. Signed and notarized, Apple silicon and Intel. 7-day free trial, then $4.99 once, no subscription. Source is MIT on GitHub. I built it.
Pricing tag: Paid (free trial). Category: Mac apps / Productivity / Utilities.
Maker comment:
Hi, I'm Pratik, I made StayAwake. I wanted to close my MacBook mid-upload without it sleeping and without buying a monitor. Honest about the limits: basic keep-awake is also free elsewhere (Amphetamine, caffeinate), and this app earns its price on the lid-closed mode and the cleanup guarantees. Questions and bug reports welcome.

---------------------------------------------------------------------

## 4. Product Hunt

Name: StayAwake
Tagline (60 chars max): Keep your Mac awake, even with the lid closed
(55 chars. Alternate: "Close the lid. Your Mac keeps working.")

Description (260 chars max):
Menu bar app that keeps your Mac awake with the lid closed, no external display needed. Auto-stop timer, restores sleep if it quits or crashes. Apple silicon and Intel. 7-day trial, then $4.99 once. I made it.
(about 205 chars)

Topics: Mac, Productivity, Menu Bar Apps, Utilities
Pricing: Paid with free trial.

First comment (as maker):
Hi Product Hunt, I'm Pratik and I built StayAwake.

The problem: start a big upload or a long build, close the laptop, and it sleeps. caffeinate and most keep-awake apps don't stop that, because a lid close is a separate trigger. Clamshell mode needs an external display and power.

What it does: Keep Awake, or Keep Awake When Lid Closed (no display needed), with an auto-stop timer. If the app quits, crashes or gets force-killed, a small helper puts normal sleep back. I tested force-kill, a normal quit and a real lid close before shipping.

Things I want to be upfront about:
- It's paid: 7-day trial, then $4.99 once. No subscription. Source is MIT on GitHub, and the license check is honor-system.
- The demo video is an animation with a simulated upload, not a screen recording.
- "Carry My Workstation" (rejoin your iPhone hotspot) is beta and not widely tested.
- Lid-closed mode in a sealed bag can get warm. It stops itself on serious heat or low battery (v1.4), but still use the timer and don't seal it in a bag. I wrote a guide on this: https://pratiknayakprojects-dev.github.io/StayAwake/keep-mac-awake-lid-closed.html

I'd love to hear what's missing.

Gallery plan (in order):
1. Hero: menu bar with the cup icon and the open menu (real screenshot).
2. The lid-closed approval prompt and "never asks again" (real screenshot).
3. Auto-stop timer: cup icon draining (screenshot).
4. Animated demo, captioned "Animation with a simulated upload, not a screen recording".
5. Comparison card: assertions vs lid close vs clamshell (simple graphic, from the guide).
6. Trial and price card: 7 days free, $4.99 once, no subscription.
Thumbnail: app icon on the warm cream background used on the site.
Launch notes: launch on a Tuesday to Thursday, 12:01am PT. You need an account and a hunter or self-hunt; do not ask for upvotes, ask for feedback.

---------------------------------------------------------------------

## 5. r/macapps

I could not load the subreddit rules from here (Reddit blocks my tools). Read the current rules and the pinned post before posting. From memory, it has required: a developer disclosure, correct post flair, a clear price and what the free tier or trial includes, and limits on how often you can self-promote. Treat that as unconfirmed.

Title: [Developer] StayAwake: menu bar app to keep your Mac awake with the lid closed ($4.99 once, 7-day trial)

Body:
I'm the developer. I built StayAwake because closing the lid on a MacBook mid-upload kills it, and caffeinate and most keep-awake apps don't prevent that.

What it does
- Keep Awake (normal power assertion), or Keep Awake When Lid Closed, with no external display
- Auto-stop timer (10 min to 3 hours)
- Lid-closed mode stops itself on serious heat or low battery (10% default)
- If the app quits, crashes or is force-killed, a helper restores normal sleep
- Universal, macOS 13+, signed and notarized

Pricing, plainly: 7-day free trial, then $4.99 once, no subscription. Source is MIT on GitHub and the license check is honor-system.

Limits: Amphetamine is free and does far more triggers and automation; if you only need basic keep-awake, use that. StayAwake is for the lid-closed case. "Carry My Workstation" (iPhone hotspot rejoin) is beta and not widely tested. Lid-closed in a bag can get hot: it stops itself on serious heat or low battery, but use the timer anyway.

Download (trial): https://github.com/pratiknayakprojects-dev/StayAwake/releases/latest/download/StayAwake.dmg · Site: https://pratiknayakprojects-dev.github.io/StayAwake/ · I wrote a guide on lid-close sleep: https://pratiknayakprojects-dev.github.io/StayAwake/keep-mac-awake-lid-closed.html
Happy to answer questions and take bug reports. If you'd like a Homebrew install: `brew install --cask pratiknayakprojects-dev/stayawake/stayawake`.

---------------------------------------------------------------------

## 6. Show HN

No Show HN text was pasted into this task, so here is a fresh one in the same plain style.

Title: Show HN: StayAwake, a Mac menu bar app that keeps it awake with the lid closed
(URL: the site, or the GitHub repo. Repo is better on HN: source is MIT.)

First comment:
I made this. A MacBook sleeps when you close the lid, even under caffeinate, because a lid close is a separate trigger from idle sleep. Clamshell mode avoids it but needs an external display and power.

StayAwake runs `pmset disablesleep` through a root helper installed with SMAppService, called over XPC. The helper only accepts callers signed with my Team ID. If the app quits, crashes or is killed, the helper restores sleep. Closed-lid mode also stops itself when ProcessInfo.thermalState reaches serious or the battery drops below a chosen percentage (IOKit power sources, 10% default). I tested kill -9, a normal quit and a real lid close.

It's paid: 7-day trial, then $4.99 once. The source is MIT and the license check is honor-system, so you can build it yourself. I wrote up how lid-close sleep works here: https://pratiknayakprojects-dev.github.io/StayAwake/keep-mac-awake-lid-closed.html. Caveats: "Carry My Workstation" (iPhone hotspot rejoin through Accessibility automation) is beta and barely tested, and the demo video on the site is an animation, not a screen recording. Happy to answer questions about the helper design.

---------------------------------------------------------------------

## 6b. Reply for the r/IMadeThis thread (where the idea came from)

Not posted. Paste as a reply to the comment asking about heat, battery and admin rights. Say you built it.

Fair question, and both were gaps in my own app (I'm the developer). It now stops lid-closed mode by itself when macOS reports serious thermal pressure, or when the battery falls below a level you pick (10% by default), and sends a notification saying why. On admin: lid-closed mode needs one, because it flips a protected pmset setting through a small helper you approve once. Plain keep-awake needs nothing. Still don't seal it in a bag; the cutoffs are a backstop.

---------------------------------------------------------------------

## 7. LATER: Gumroad affiliates (not enabled)

1. Gumroad dashboard > Products > StayAwake > Share tab > turn on affiliates / set a commission (start 30% of $4.99, about $1.50 each).
2. At $4.99 the margin is thin after Gumroad's fee. Decide if 30% is worth it; 20% is a floor.
3. Create an affiliate sign-up link and put it on a small /affiliates mention only once someone actually asks. Candidates: Mac utility reviewers and newsletters.
4. Rule for affiliates: they must disclose the affiliate link. Add this to the sign-up note.
5. Revisit after there are at least a few real sales. Not worth the effort before that.

## 8. LATER: Setapp application (not started)

1. Apply at the Setapp developer page ("Join Setapp as a developer"). It's free to apply. Expect a review of app quality and fit.
2. Their app fit: Setapp is subscription-based for users, and developers are paid from usage share. Apps are generally expected to be polished, notarized, and not sold separately in a way that conflicts. Check the current terms before applying, especially about how a Setapp build differs from the Gumroad build (no license check, separate bundle build).
3. Prepare: a no-license-check build flag, a Setapp-ready build, screenshots, a short pitch ("closed-lid keep-awake with safe cleanup"), notarized DMG, support contact.
4. Honest risk: the keep-awake category is crowded and Amphetamine is free, so expect scrutiny. Apply after there is some usage and a few reviews.
5. Needs your account and your sign-off on terms. I won't submit.
