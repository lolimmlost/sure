# Features to Port from Financial-Planner

Sourced from [lolimmlost/Financial-Planner](https://github.com/lolimmlost/Financial-Planner) issues. These are features the old app had (or planned) that Sure doesn't yet cover.

---

## High Priority

### Debt Analysis & Propensity Metrics (#75)
Sure tracks loans and credit cards but lacks dedicated analysis tools. Port: debt-to-income ratio, snowball/avalanche calculators, consolidation analyzer, debt-free date projections. Fits naturally with existing loan/credit card account types.

### Spending Insights & Analysis (#74)
Sure has category-level spending in reports but lacks anomaly detection, subscription detection, merchant analysis, spending forecasting, and seasonal pattern recognition. Would enhance the existing `IncomeStatement` and reports views.

### Notifications & Alerts (#82)
Sure has no notification system. Budget overspending alerts, bill reminders, goal milestones, and unusual spending detection would add significant value. Can integrate with the existing Sidekiq background processing.

### Bill & Subscription Management UI (#67)
Sure has `RecurringTransaction` model but lacks a dedicated bill/subscription management interface: template management, upcoming instances view, skip/modify instances, mark-as-paid. The model infrastructure exists; the UI is minimal.

---

## Medium Priority

### Tax Planning & Estimation (#78)
Sure has no tax-related tools. Tax bracket calculator, capital gains calculator, deduction tracker, and quarterly estimator would complement the existing financial statements.

### Goal Optimization Engine (#70)
Sure has goals with basic progress tracking but lacks optimization: savings allocation across goals, trade-off analysis, timeline optimization, and scenario modeling.

### Goal Contributions with Transactions (#69)
Sure links goals to accounts and budget categories, but lacks transaction-level contribution linking, auto-tracking rules, and contribution timelines.

### Advanced Search & Filter (#84)
Sure has `EntrySearch` but lacks saved searches, search history, and natural language search. The AI assistant partially covers NLP queries, but a dedicated search UI would be valuable.

---

## Lower Priority

### Dashboard Customization (#83)
Sure has a fixed dashboard layout. Draggable widgets, widget library, and layout persistence would let users personalize their view.

### Insurance Management (#79)
Sure has no insurance tracking. Policy tracking, premium payments, renewal reminders, and claim tracking could be a new account type or module.

### Estate Planning Tools (#96)
Beneficiary management and asset distribution planning could complement existing asset tracking.

### Charitable Giving Tracker (#95)
Could be implemented as a category-based report or dedicated module for donation tracking and tax-deductible receipt management.
