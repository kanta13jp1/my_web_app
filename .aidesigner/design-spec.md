# 自分株式会社 — AIDesigner Design Spec

> Feed this file to AIDesigner MCP when generating UI variants.

## App Identity

- **Product**: 自分株式会社 (Jibun Kabushiki Kaisha)
- **Category**: AI Life Management Platform
- **Tagline**: Notion・Evernote・MoneyForward・Slack・X を1つに。完全無料。
- **URL**: https://my-web-app-b67f4.web.app/

## Visual Direction

**Mood**: Professional dark × vitality orange. Like a terminal for your life.
**Inspiration**: Linear (dark, sharp) × Spotify (orange energy) × note.com (Japanese typography)
**NOT**: Corporate blue, pastel, gradients everywhere, light mode

## Color System

```
BACKGROUND
  surface1: #0A0A0A  ← page bg
  surface2: #1A1A1A  ← AppBar, elevated surface
  surface3: #1E1E1E  ← content cards
  surface4: #2A2A2A  ← inputs, chips, dividers

BRAND
  orange:        #FF6B35  ← primary CTA, links, focus rings
  orange-light:  #FF8C5A
  orange-dark:   #CC4A1A
  indigo:        #3D5AFE  ← AI badges, premium features
  indigo-light:  #7986CB

SEMANTIC
  success: #4CAF50
  error:   #E53935
  warning: #FFC107
  gold:    #FFD700  ← rank #1 only

TEXT
  primary:   #FFFFFF
  secondary: #B0B0B0
  tertiary:  #707070
```

## Typography

```
Font: Noto Sans JP (ja), then system fallback
Scale:
  H1: 24px / bold / 1.4lh / 0.96px ls
  H2: 18px / bold / 1.4lh / 0.72px ls
  Body-L: 16px / regular / 1.7lh (min for Japanese!)
  Body-M: 14px / regular / 1.7lh
  Body-S: 12px / regular / 1.6lh
  Label: 11px / medium / 1.5lh / 0.5px ls
  Code: SFMono / Consolas / 13px
```

## Component Patterns

### Card
- bg: surface3 (#1E1E1E)
- border: 1px solid rgba(255,255,255,0.08)
- radius: 12px
- shadow: rgba(0,0,0,0.3) 0px 2px 8px

### Primary Button (Orange CTA)
- bg: #FF6B35
- text: white, 14px bold
- radius: 8px
- height: 40px (desktop), 44px (mobile)

### Secondary Button
- border: 1px solid #FF6B35
- text: #FF6B35
- bg: transparent

### AppBar
- bg: #1A1A1A
- border-bottom: 1px solid rgba(255,255,255,0.08)
- height: 56px
- title: white, 16px, bold

### Section Header (category label)
- text: #FF6B35
- 11px / bold / 1.2px letter-spacing / uppercase

### Status Badges
- Compliant: bg #4CAF50 10% + text #81C784
- Needs Work: bg #FFC107 10% + text #FFC107
- Pending:    bg #E53935 10% + text #EF9A9A
- Not Audited: bg rgba(255,255,255,0.05) + text #707070

### Compliance Dot
- Pass: #4CAF50
- Fail: #E53935
- 8px circle

## Spacing

4px base grid:
4, 8, 12, 16, 20, 24, 32, 48, 64

Page padding: 16px
Card inner padding: 16px
Section gap: 24px
Item gap: 12px

## Glow Effects (use sparingly)

Orange glow: box-shadow rgba(255,107,53,0.30) 0px 0px 12px 2px
Indigo glow: box-shadow rgba(61,90,254,0.30) 0px 0px 12px 2px

## Page Layout

Max content width: 960px (centered)
Single column on mobile (<600px)
Two column possible on tablet+

## Key UI Patterns

1. **Empty state**: icon (40px, surface4 bg) + title + subtitle + CTA button
2. **Loading**: CircularProgressIndicator(color: #FF6B35)
3. **Error**: EF9A9A text + retry button
4. **Section divider**: 1px rgba(255,255,255,0.06) + 24px vertical margin
5. **Progress bar**: LinearProgressIndicator(color: #FF6B35, bg: surface4)
6. **Chip**: surface4 bg + #B0B0B0 text, radius 999px

## AI Feature Styling

Pages with AI: add indigo accent
- AI badge: indigo bg 15% + indigo text + robot icon
- AI glow on cards: subtle indigo box-shadow

## Anti-patterns (Never Do)

- White/light backgrounds
- withOpacity() — use withValues(alpha:)
- Blue as primary color
- Letter-spacing on body text
- line-height < 1.4
- Font size < 10px
- Touch target < 44×44px
