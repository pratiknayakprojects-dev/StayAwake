# StayAwake: where to post, and how to keep growing search traffic

Rules for everything below: say you built it, call the video an animation, call Carry My Workstation beta, never claim free forever or the Mac App Store, no invented numbers or reviews, don't ask for upvotes.

I could not post to Reddit myself (my browser tools refuse reddit.com), so the Reddit posts below are for you to paste. Reddit rules change and moderators have the last word. Read each sidebar first.

## 1. Reddit: which subreddits, in what order

| Order | Subreddit | Fit | How to approach |
|---|---|---|---|
| 1 | r/macapps | Best audience for paid Mac utilities | Third-party summaries say developer posts need moderator permission or go in a megathread, with limits per developer. Send a short modmail first, using the template below. Do not post cold. |
| 2 | r/MacOS, r/macbookpro, r/MacBookAir | People hit "lid close kills my upload" constantly | Do NOT post the app. Answer existing questions ("how do I keep my MacBook awake with the lid closed") with a helpful reply that links the guide, and disclose that you made StayAwake if you mention it. Check each sub's self-promotion rule first. |
| 3 | r/SideProject | Friendly to "I built this" posts | Post as a build story: why, how the helper survives a kill -9, what you'd change. |
| 4 | r/indiehackers | Same | Post about pricing a $4.99 one-time Mac utility and what you learned. |
| skip | r/apple, r/mac | Ban or heavily restrict promotion | Don't post. |

### Modmail template for r/macapps
Subject: Permission to post a paid Mac utility (developer disclosure)

Hi mods, I'm the developer of StayAwake, a menu bar app that keeps a Mac awake with the lid closed. It's paid ($4.99 one-time, 7-day free trial), the source is MIT on GitHub, and I'll disclose that I made it in the post. Is it OK to post it as a developer post, or would you prefer I wait for the megathread? Happy to follow whichever format you want. Thanks.

### r/macapps post (once they say yes)
Use section 5 of LISTINGS.md. Attach the three real screenshots in demo/real/. Title starts with [Developer].

### r/SideProject post
Title: I built a Mac menu bar app that keeps the laptop awake with the lid closed. What I learned about the safety side
Body: why closing the lid sleeps a Mac even under caffeinate; how the helper restores sleep if the app dies; what I tested (kill -9, normal quit, a real lid close); price and trial; links (site, guide, source); ask what's missing. Disclose that you built it, say Carry My Workstation is beta, say the video is an animation.

### r/indiehackers post
Title: Pricing a tiny Mac utility at $4.99 one-time with a 7-day trial: what I'd do differently
Body: honest numbers only from scripts/stats.sh, nothing invented. If you have no numbers yet, wait a few weeks and post then.

## 2. Other places to distribute it, besides Reddit

Highest value first:
1. **Q&A answers (Ask Different / Stack Exchange, Apple Support Communities).** People search "keep MacBook awake lid closed". A genuine answer that explains pmset and caffeinate, links the guide, and discloses you built StayAwake can rank for years. Highest return for effort.
2. **Show HN.** Post the repo or the site, with the comment in LISTINGS.md section 6. Only when you can answer for several hours.
3. **Product Hunt.** Gallery plan is in LISTINGS.md section 4. Use the real screenshots. Launch when you can be online all day.
4. **GitHub: awesome-mac list.** The sindresorhus-style "awesome" lists for Mac apps accept pull requests for open-source apps. Check their contribution guide, then open a PR.
5. **Directories:** MacMenuBar (a curated list of menu bar apps), SaaSHub, Slant, Gumroad Discover (turn it on in your Gumroad product settings), AlternativeTo (done), MacUpdate (done), Uneed (scheduled).
6. **Write-ups on dev.to or Hashnode.** Repost the lid-close guide with a canonical link to your site so search credit goes to your page.
7. **Social.** A short post on X, Mastodon or Bluesky with the real screenshots and the video. Low reach, but it's free and gives you a link to share.
8. **Press and newsletters.** Mac roundup writers and newsletters occasionally cover small utilities. Send a short, honest email with the link and a screenshot. Low odds, low cost.
9. **Later:** Gumroad affiliates and Setapp (plans in LISTINGS.md).

## 3. Keeping the website working for search

Done so far: guide page, comparison page, sitemap, robots, canonical and OG tags, and structured data on the landing page.

Next steps, in order:
1. **Google Search Console and Bing Webmaster Tools.** Add the site, verify it, and submit sitemap.xml. This is the single biggest accelerator. It needs your Google and Microsoft accounts. Verification is one meta tag, which I can add when you give me the token.
2. **More pages, each aimed at a question people actually search:**
   - "Why does my Mac sleep when I close the lid while a download is running"
   - "What does sudo pmset -a disablesleep do, and is it safe?"
   - "caffeinate command cheat sheet for Mac"
   - "Keep Mac awake during a long upload, build or backup"
   Each should be genuinely useful first, with a short clear link to the app. I can write these one at a time.
3. **Real screenshots on the landing page and guide,** with descriptive alt text. They're in demo/real/.
4. **A changelog page,** one line per release. Fresh content and a reason for people to link to it.
5. **Links to the site from everywhere above.** Search rankings depend mostly on other sites linking to you.
6. **Custom domain (optional, costs money).** A github.io address ranks fine, but your own domain is easier to remember and keep. Ask before buying anything.
7. **Re-check every few weeks.** Update the guide when macOS changes behavior, and keep the facts accurate.

## 4. Suggested order for the next two weeks
- Day 1: modmail to r/macapps; answer 2 to 3 existing Q&A threads.
- Day 2 to 3: Search Console and Bing, submit sitemap; send me the token if you want me to add it.
- Day 4 to 7: one new guide page; post to r/SideProject.
- Week 2: Show HN, on a day you're free. Product Hunt after that.
- Run scripts/stats.sh weekly and keep only what sends downloads.
