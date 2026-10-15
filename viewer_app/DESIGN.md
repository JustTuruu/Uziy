---
name: Uziy
description: Watch a brand's video, answer a few questions, get tögrög — a calm green ledger for small earnings.
colors:
  meadow-paper: "#F5F7F3"
  sheet-white: "#FFFFFF"
  sage-wash: "#EDF2EC"
  sage-highlight: "#E1E9E1"
  forest: "#145C45"
  forest-deep: "#104C39"
  on-forest: "#FFFFFF"
  coin-gold-light: "#F2D48A"
  coin-ink: "#775521"
  ink: "#192D25"
  ink-soft: "#53675C"
  ink-quiet: "#5D7063"
  sage-hairline: "#E0E7DD"
  sage-line: "#C4D1C3"
  divider: "#DBE4DA"
  success: "#12633D"
  warning: "#805109"
  danger: "#BD3934"
  night-paper: "#0E1713"
  night-sheet: "#18251E"
  night-mint: "#9ADBB5"
typography:
  display:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "34px"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-1px"
  display-small:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "28px"
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: "-0.6px"
  page-title:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "26px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.5px"
  title:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "-0.2px"
  body:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "15px"
    fontWeight: 500
    lineHeight: 1.45
  body-small:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.45
  label:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "0.1px"
  button:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.1px"
  caption:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "12.5px"
    fontWeight: 500
    lineHeight: 1.35
  money:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "17px"
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: "-0.3px"
    fontFeature: "tnum"
  money-large:
    fontFamily: "SF Pro (platform system font)"
    fontSize: "40px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "-1.2px"
    fontFeature: "tnum"
rounded:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "28px"
  pill: "999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
  huge: "48px"
  gutter: "20px"
components:
  button-primary:
    backgroundColor: "{colors.forest}"
    textColor: "{colors.on-forest}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "54px"
    padding: "0 22px"
  button-secondary:
    backgroundColor: "{colors.sage-wash}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "54px"
  button-disabled:
    backgroundColor: "{colors.sage-wash}"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.md}"
  input:
    backgroundColor: "{colors.sheet-white}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "17px 16px"
  card:
    backgroundColor: "{colors.sheet-white}"
    rounded: "{rounded.lg}"
    padding: "16px"
  pill-quiet:
    backgroundColor: "{colors.sheet-white}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 16px"
---

# Design System: Uziy

## Overview

**Creative North Star: "The Meadow Ledger"**

Uziy is a small ledger kept on good paper: a warm, almost-white sheet (meadow paper), entries in deep forest ink, and the coin is the Uziy mark struck on a green disc. The viewer comes here in short idle moments to earn a few hundred tögrög, so every screen reads like a calm, exact account of what they can earn, what they earned and what happens next. Trust comes from precision — exact amounts, aligned columns, honest states — not from decoration.

The world is quiet and flat by default. Colour is spent on two things only: the forest green that marks the one action to take, and the soft gold of the reward chip that marks money. Everything else is paper, sage hairlines and ink. Depth appears only where a hand will land (the main button, the fields being filled), and the sign-in page alone carries faint sage paper folds in its background, like a watermark on the first sheet.

**Key Characteristics:**
- Meadow paper background, white sheets, sage hairlines; forest green for action, gold only for money.
- One confident primary action per screen; everything else steps back.
- System font (SF Pro on iPhone) with tabular figures for every amount.
- Light and dark appearance are both first-class; dark is forest night with a mint action colour.
- Plain fills over gradients: the owner's rule, "plain fills read as hand-made".

## Colors

A green-and-paper palette with a single precious accent: forest for doing, gold for money, sage for structure.

### Primary
- **Forest** (#145C45): the action colour — primary buttons, focused field outlines, links such as 'Нууц үг мартсан?', selected segments and checkboxes. Text on it is white.
- **Forest Deep** (#104C39): pressed / emphasised forest and the dark end of the wallet card.

### Secondary
- **Coin Gold Light** (#F2D48A) with **Coin Ink** (#775521): the reward chip's flat fill and its amount. Gold never colours buttons, text blocks or backgrounds.

### Neutral
- **Meadow Paper** (#F5F7F3): every screen's background.
- **Sheet White** (#FFFFFF): cards, fields, sheets.
- **Sage Wash** (#EDF2EC) / **Sage Highlight** (#E1E9E1): secondary buttons, icon tiles, the '+976' capsule, quiet tinted panels.
- **Ink** (#192D25): titles and body text. **Ink Soft** (#53675C): labels, subtitles, secondary text. **Ink Quiet** (#5D7063): hints and placeholders (still ≥ 4.5:1 on paper).
- **Sage Hairline** (#E0E7DD), **Sage Line** (#C4D1C3), **Divider** (#DBE4DA): borders — hairline for cards, line for inputs and secondary buttons.
- **Night Paper / Night Sheet / Night Mint** (#0E1713 / #18251E / #9ADBB5): the dark appearance's background, surfaces and action colour (text on mint is dark green).

Semantic: **Success** (#12633D), **Warning** (#805109), **Danger** (#BD3934) for statuses and errors only.

**The Two Colours Of Meaning Rule.** Forest means "act here", gold means "money". If something is neither an action nor money, it is paper, sage or ink.

**The Plain Fill Rule.** Buttons, chips and cards are flat fills. Gradients are reserved for fixed artwork (the green wallet card); never on controls, coins or text.

## Typography

**Display / Body Font:** the platform system font — SF Pro on iPhone, Roboto on Android (no bundled family; full Mongolian Cyrillic coverage).

**Character:** one family, carried by weight and size: heavy (800) for big numbers and page-level words, bold (700) for titles and buttons, medium (500) for reading text.

### Hierarchy
- **Display** (800, 34px, 1.1, −1px): rare big statements.
- **Auth Title** (800, 40px, `AuthPageTitle`): the one big word of every auth page, with an optional Body subtitle in Ink Soft.
- **Page Title** (700, 26px, 1.2): the title on top of each tab — Нүүр, Хэтэвч, Профайл.
- **Title** (700, 18px): card and section titles.
- **Body** (500, 15px, 1.45): reading text, field values. **Body Small** (500, 13px): helper paragraphs.
- **Label** (600, 14px): field labels above inputs, pills, links.
- **Button** (700, 16px): button labels.
- **Caption** (500, 12.5px): metadata, helper and error lines under fields.
- **Money** (800, 17px, tabular) / **Money Large** (800, 40px, tabular): every ₮ amount.

**The Tabular Money Rule.** Every amount uses the money styles with tabular figures, so balances never jitter while they count.

**The Label Above Rule.** Fields carry a visible label above them; placeholders are hints, never the only name of a field.

## Layout

A single column inside a 20px gutter, capped at 560px and centred on wide screens. Spacing follows a 4/8 scale (2, 4, 8, 12, 16, 20, 24, 32, 48). Tight intervals (8–12px) bind a label to its field or a title to its subtitle; generous intervals (32–56px) separate groups. Every scrolling form sits in a viewport-tall scroll area so short phones scroll and tall phones keep their composition; the keyboard simply closes free space. Touch targets are at least 44pt. The bottom tab bar is fixed: Нүүр, Хэтэвч, Профайл, icon above label.

## Elevation & Depth

Flat by default, lifted only where a hand lands. Surfaces separate by tone (paper → white sheet → sage wash) and hairlines, not shadows.

### Shadow Vocabulary
- **Raised action** (fill colour at 18 %, blur 20, offset 0/6): the one main button of an auth page (`AppButton(raised: true)`), e.g. 'Нэвтрэх', 'Үргэлжлүүлэх'; a forward step also carries the right-edge arrow.
- **Raised field** (ink at 7 %, blur 14, offset 0/4; black 35 % on dark): fields of the short auth forms — sign-in, forgot password, phone check, new password (`LoginFieldsTheme(raised: true)`), painted only outside the field so the white fill stays clean. The long registration form keeps flat fields.
- **Logo tile** (forest glow, soft): the white logo tile on splash and sign-in.

**The Raised Only Where You Act Rule.** At most one raised button per screen; cards, lists and chips stay flat.

## Shapes

Gently rounded throughout. Inputs, buttons and field-like tiles share one corner (16px); cards use 20px; small chips 8–12px; pills (guest link, balance pill, tags) are fully rounded. Borders are 1px sage lines, 1.5px forest when focused. The sign-in background adds soft circular swells and paper folds — never sharp geometry.

## Components

### Buttons
- **Shape:** gently rounded (16px), 54px tall, full width by default.
- **Primary:** forest fill, white bold label; may carry a right-edge arrow (`trailingIcon`) with the label still centred.
- **Secondary:** sage wash with a sage line border, ink label — the quiet alternative ('Бүртгүүлэх' under the sign-in button).
- **Press / Loading / Disabled:** presses scale to 0.97 with a light haptic; loading swaps the label for a spinner and ignores taps; disabled turns sage with soft ink.

### Inputs / Fields
- **Style:** white fill, 1px sage line, 16px corners, 17×16px padding, label above in Label style.
- **Focus:** the outline turns forest (1.5px) and the label above turns forest, over 150ms.
- **Error:** danger outline and a caption under the field; sign-in fields reserve that line so errors never push the form.
- **Phone:** '+976' prefix (on a sage capsule with a hairline divider on the sign-in page), digit keypad, 8 digits.

### Cards / Containers
- **Corner Style:** 20px. **Background:** white on paper. **Border:** sage hairline. **Shadow:** none. **Padding:** 16px.

### Pills & Chips
- **Quiet pill:** see-through white, sage line, ink label, optional chevron — navigation that must not compete (the guest link).
- **Reward chip:** flat gold, used only beside amounts.

### Back control
- Auth steps use `AuthBackButton`: a 44pt see-through round button with a sage line and a chevron, sitting on the 20px gutter.

### Navigation
- Fixed bottom bar, three tabs, icon with its label underneath; the active tab uses the filled icon in the action colour. No tab animation.

### Signature: The Coin and the Wallet Card
The coin (`CoinIcon`) is the Uziy mark (`assets/logo_mark.png`) tinted in the on-action colour on a flat disc of the action colour, with a thin inner ring from 20px up — forest + white in light, mint + dark green in dark (owner, 2026-10-14: the lit gold ₮ coin did not belong to the flat green UI). It sits inside the gold reward chip and beside amounts. The wallet card is a bank-card-proportioned forest sheet with white ink — the one fixed dark surface in light mode.

## Do's and Don'ts

### Do:
- **Do** keep one primary (forest) action per screen and make it the only raised element.
- **Do** show money with the money styles, the coin and the gold reward chip; nothing else gets gold.
- **Do** put a visible label above every field and keep placeholders as short hints.
- **Do** read colours from the theme (`context.colors`) so light and dark both work; check text contrast stays AA in both.
- **Do** honour reduce-motion: transitions of 150–250ms, none when reduced.

### Don't:
- **Don't** use gradients, glows or glass on buttons, chips, cards or text.
- **Don't** introduce colours outside this palette (no blue, purple or neon accents in UI).
- **Don't** stack two full-width primary buttons on one screen.
- **Don't** add background decoration outside the sign-in page's faint paper folds.
- **Don't** use Latin copy in the UI or the word "админ" in viewer-facing text.
