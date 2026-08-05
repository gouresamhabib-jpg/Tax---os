# TaxOS — UI Guidelines

**Document ID:** DOC-05  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** Design, engineering, product

---

## 1. Design philosophy

TaxOS UI must feel **calm, competent, and clear**. Users arrive with tax anxiety — our interface reduces stress through generous whitespace, plain language, progressive disclosure, and consistent patterns. Every screen should answer: "What do I need to do next?"

---

## 2. Design principles

| Principle | Application |
|-----------|-------------|
| **Clarity over cleverness** | Obvious labels, no jargon without explanation |
| **Progressive disclosure** | Show only what's needed at each step; reveal complexity gradually |
| **Calm confidence** | Soft palette, rounded corners, no alarming reds unless for errors |
| **Thumb-first** | Primary actions reachable with one hand on mobile |
| **Forgiving** | Easy undo, clear confirmation dialogs for destructive actions |
| **Accessible by default** | WCAG 2.1 AA contrast, screen reader labels, scalable text |
| **Consistent** | Same patterns for same interactions across all features |

---

## 3. Color system

### 3.1 Brand palette

| Token | Light mode | Dark mode | Usage |
|-------|-----------|-----------|-------|
| `primary` | `#2563EB` (Blue 600) | `#3B82F6` (Blue 500) | Primary actions, links, active states |
| `primaryContainer` | `#DBEAFE` (Blue 100) | `#1E3A5F` | Selected chips, highlighted cards |
| `secondary` | `#059669` (Emerald 600) | `#10B981` (Emerald 500) | Success states, positive amounts (refunds) |
| `secondaryContainer` | `#D1FAE5` (Emerald 100) | `#064E3B` | Success backgrounds |
| `tertiary` | `#7C3AED` (Violet 600) | `#8B5CF6` (Violet 500) | Premium features, upsell accents |
| `error` | `#DC2626` (Red 600) | `#EF4444` (Red 500) | Errors, amount owed, destructive actions |
| `errorContainer` | `#FEE2E2` (Red 100) | `#7F1D1D` | Error backgrounds |
| `warning` | `#D97706` (Amber 600) | `#F59E0B` (Amber 500) | Deadlines approaching, caution |
| `surface` | `#FFFFFF` | `#1A1A2E` | Page backgrounds |
| `surfaceVariant` | `#F8FAFC` (Slate 50) | `#252540` | Card backgrounds, input fields |
| `onSurface` | `#0F172A` (Slate 900) | `#F1F5F9` (Slate 100) | Primary text |
| `onSurfaceVariant` | `#64748B` (Slate 500) | `#94A3B8` (Slate 400) | Secondary text, hints |
| `outline` | `#E2E8F0` (Slate 200) | `#334155` (Slate 700) | Borders, dividers |

### 3.2 Semantic colors

| Context | Color | Example |
|---------|-------|---------|
| Refund (positive) | `secondary` (green) | "+$2,450 refund" |
| Amount owed (negative) | `error` (red) | "$1,200 owed" |
| Neutral amount | `onSurface` | "$45,000 income" |
| Deadline urgent (< 7 days) | `warning` | "File by April 15" |
| Deadline passed | `error` | "Overdue" |
| Filing complete | `secondary` | "Return submitted" |
| Draft/in progress | `primary` | "60% complete" |

---

## 4. Typography

### 4.1 Font family

| Platform | Font | Fallback |
|----------|------|----------|
| All | **Inter** | SF Pro (iOS), Roboto (Android) |

Inter is loaded from `assets/fonts/` for cross-platform consistency.

### 4.2 Type scale

| Token | Size | Weight | Line height | Usage |
|-------|------|--------|-------------|-------|
| `displayLarge` | 32 sp | 700 (Bold) | 1.2 | Dashboard hero numbers (refund amount) |
| `displayMedium` | 28 sp | 700 | 1.2 | Section headers |
| `headlineLarge` | 24 sp | 600 (SemiBold) | 1.3 | Page titles |
| `headlineMedium` | 20 sp | 600 | 1.3 | Card titles |
| `titleLarge` | 18 sp | 600 | 1.4 | List item titles |
| `titleMedium` | 16 sp | 500 (Medium) | 1.4 | Subsection headers |
| `bodyLarge` | 16 sp | 400 (Regular) | 1.5 | Primary body text |
| `bodyMedium` | 14 sp | 400 | 1.5 | Secondary body text |
| `bodySmall` | 12 sp | 400 | 1.5 | Captions, timestamps |
| `labelLarge` | 14 sp | 500 | 1.4 | Button text |
| `labelMedium` | 12 sp | 500 | 1.4 | Chips, badges |
| `labelSmall` | 10 sp | 500 | 1.4 | Overline labels |

### 4.3 Typography rules

- Maximum 2 font weights per screen (typically Regular + SemiBold)
- Currency amounts always use `displayLarge` or `headlineLarge` with tabular figures
- Tax jargon must include a tooltip or helper text on first occurrence
- Line length: 40–60 characters for body text on mobile

---

## 5. Spacing and layout

### 5.1 Spacing scale (4 pt base grid)

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4 pt | Icon-to-text gap |
| `sm` | 8 pt | Inline element spacing |
| `md` | 16 pt | Standard padding, card internal spacing |
| `lg` | 24 pt | Section spacing |
| `xl` | 32 pt | Page top/bottom padding |
| `xxl` | 48 pt | Major section breaks |

### 5.2 Layout rules

| Rule | Value |
|------|-------|
| Screen horizontal padding | 16 pt |
| Card internal padding | 16 pt |
| Card border radius | 12 pt |
| Button border radius | 8 pt |
| Input border radius | 8 pt |
| Card elevation (light) | 1 dp shadow |
| Minimum touch target | 44 × 44 pt |
| Bottom navigation height | 56 pt + safe area |
| App bar height | 56 pt |

---

## 6. Component library

All shared components live in `lib/shared/widgets/`. Feature-specific widgets stay in their feature folder.

### 6.1 Buttons

| Variant | Usage | Style |
|---------|-------|-------|
| **Primary** | Main action per screen (one only) | Filled, `primary` color, white text |
| **Secondary** | Alternative actions | Outlined, `primary` border and text |
| **Tertiary** | Low-emphasis actions | Text only, `primary` color |
| **Destructive** | Delete, cancel subscription | Filled or outlined, `error` color |
| **FAB** | Quick add (expense, document) | Floating, `primary`, icon + optional label |

**Rules:**
- One primary button per screen
- Button text is verb-first: "Add expense", "Continue", "File return"
- Disabled state: 38% opacity, no interaction
- Loading state: spinner replaces text, button remains same size

### 6.2 Input fields

| Type | Usage |
|------|-------|
| Text | Name, description, search |
| Currency | Amount fields with `$` prefix, decimal formatting |
| Date | Date picker with calendar overlay |
| Select | Dropdown for categories, filing status |
| Multi-select | Income types, deductions checklist |
| SSN/TIN | Masked input (show last 4 only) |
| File upload | Drag/drop zone or camera button |

**Rules:**
- Label above field (not placeholder-only)
- Helper text below for complex fields
- Error text below in `error` color with icon
- Required fields marked with asterisk

### 6.3 Cards

| Variant | Usage |
|---------|-------|
| **Summary card** | Dashboard metrics (refund, income, expenses) |
| **List card** | Expense item, document item, notification |
| **Action card** | Quick action with icon, title, chevron |
| **Progress card** | Filing progress with bar and percentage |
| **Upsell card** | Plan upgrade prompt |

### 6.4 Navigation

| Component | Usage |
|-----------|-------|
| **Bottom nav bar** | 5 tabs: Dashboard, Expenses, Filing, Documents, More |
| **App bar** | Page title, back button, optional actions |
| **Tab bar** | Sub-navigation within a feature (e.g., Expenses: All / Business / Personal) |
| **Drawer** | Settings, profile, subscription, help (via "More" tab) |

### 6.5 Feedback

| Component | Usage |
|-----------|-------|
| **Snackbar** | Brief confirmation ("Expense saved") |
| **Dialog** | Destructive confirmations, important alerts |
| **Bottom sheet** | Filters, category picker, action menus |
| **Banner** | Persistent alerts (complete onboarding, upgrade plan) |
| **Empty state** | Illustration + message + CTA when no data |
| **Skeleton loader** | Content placeholder during loading |
| **Progress indicator** | Linear (filing progress) or circular (loading) |

---

## 7. Screen patterns

### 7.1 Dashboard

- Hero card: estimated refund/owed (large number, color-coded)
- Quick action row: 4 icon buttons (Add expense, Upload, File, Reports)
- Filing progress card (if return in progress)
- Upcoming deadlines list
- Recent activity feed

### 7.2 List screens (expenses, documents, invoices)

- Search bar at top
- Filter chips (category, date range, status)
- Sortable list with swipe actions (edit, delete)
- FAB for add action
- Empty state with illustration when no items

### 7.3 Form screens (add expense, income entry)

- Single column layout
- One question per screen for wizard flows
- Progress indicator at top for multi-step forms
- Sticky bottom bar with "Continue" / "Save" button
- Back navigation preserves entered data

### 7.4 Filing wizard

- Step indicator: Personal → Income → Deductions → Credits → Review → Submit
- Each step is a focused screen with clear instructions
- "Why we ask this" expandable section for complex questions
- Running tax estimate visible in persistent footer
- Review screen: summary cards with edit links per section

### 7.5 Settings

- Grouped list items with icons
- Toggle switches for boolean preferences
- Chevron navigation for sub-screens
- Destructive actions (delete account) at bottom in red

---

## 8. Iconography

| Library | Usage |
|---------|-------|
| Material Symbols (rounded) | Primary icon set |

| Context | Icon style |
|---------|-----------|
| Navigation | Outlined, 24 dp |
| Actions | Outlined, 24 dp |
| Status indicators | Filled, 16 dp |
| Empty states | Custom illustrations (Lottie or SVG), 120 dp |

---

## 9. Motion and animation

| Pattern | Duration | Curve |
|---------|----------|-------|
| Page transition | 300 ms | `easeInOut` |
| Bottom sheet open | 250 ms | `easeOut` |
| Fade in content | 200 ms | `easeIn` |
| Skeleton shimmer | 1500 ms | Linear, repeating |
| Success checkmark | 400 ms | `elasticOut` |
| FAB expand | 200 ms | `easeInOut` |

**Rules:**
- Respect system "reduce motion" setting
- No animation on initial app load (show content immediately)
- Loading states use skeleton, not spinners (except buttons)

---

## 10. Dark mode

- Full dark theme support via Material 3 `ThemeData`
- Default: follow system setting
- User override in Settings
- All colors have dark variants (see Section 3.1)
- Images and illustrations: use dark-mode variants where needed
- Elevation in dark mode: use surface tint instead of shadow

---

## 11. Accessibility requirements

| Requirement | Standard | Implementation |
|-------------|----------|----------------|
| Color contrast (text) | 4.5:1 minimum | Verified for all text/background pairs |
| Color contrast (large text) | 3:1 minimum | Headlines, display numbers |
| Touch targets | 44 × 44 pt minimum | All interactive elements |
| Screen reader | Full support | Semantic labels on all widgets |
| Focus order | Logical top-to-bottom | Verified in widget tests |
| Text scaling | Up to 200% | No clipped text at max scale |
| Color independence | Never color-only | Icons/shapes accompany color indicators |
| Motion | Reduce motion support | Disable animations when system setting on |

---

## 12. Responsive behavior

TaxOS is **mobile-first**. Tablet support is adaptive but not primary.

| Breakpoint | Layout |
|------------|--------|
| < 600 dp (phone) | Single column, bottom nav |
| 600–840 dp (tablet portrait) | Single column, wider cards |
| > 840 dp (tablet landscape) | Two-column where appropriate (list + detail) |

---

## 13. Empty states

Every list screen must have an empty state:

| Screen | Illustration | Message | CTA |
|--------|-------------|---------|-----|
| Expenses | Receipt icon | "No expenses yet" | "Add your first expense" |
| Documents | Folder icon | "No documents uploaded" | "Upload a document" |
| Filing | Form icon | "Ready to file?" | "Start your return" |
| Invoices | Invoice icon | "No invoices created" | "Create an invoice" |
| Notifications | Bell icon | "All caught up" | — |

---

## 14. Do's and don'ts

| Do | Don't |
|----|-------|
| Use plain language ("Money you earned" not "Gross income") | Use IRS form numbers without explanation |
| Show dollar amounts formatted ($1,234.56) | Show unformatted numbers (1234.56) |
| Confirm before destructive actions | Delete without confirmation |
| Provide loading feedback | Show blank screens while loading |
| Use consistent iconography | Mix icon styles/libraries |
| Test with screen reader | Rely on color alone for status |
| Keep forms short and focused | Present entire tax return on one screen |

---

**Related documents:** [06_FLUTTER_GUIDE.md](06_FLUTTER_GUIDE.md) · [01_PRODUCT_VISION.md](01_PRODUCT_VISION.md) · [10_CODING_STANDARD.md](10_CODING_STANDARD.md)
