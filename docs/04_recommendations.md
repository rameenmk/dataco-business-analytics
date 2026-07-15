# DataCo Business Performance Review — Findings and Recommendations

Prepared from an analysis of 180,519 order lines, January 2015 to September 2017.

## Summary

The business is growing and profitable, but three issues are holding back
performance. Delivery promises on premium shipping are set higher than the
operation can meet. More than half of all order value has never been collected.
And every fraud flag in three years traces to a single payment method, which
points to a system rule rather than real fraud. None of these require new
spending to address. They require changing how a few things are set up.

## Finding 1 — Premium shipping promises cannot be met

First Class quotes next-day delivery and misses that window 95% of the time,
because it actually takes two days on average. Second Class quotes two days and
takes four. Standard Class, which quotes four days, is the only reliable tier at
38% late. The company is late on 54.8% of all shipments, and the rate has not
improved in three years.

The cause is not warehouse speed. It is that the quoted windows on the fast tiers
are set tighter than the operation can deliver. In fact, one third of all order
lines miss by exactly one day.

**Recommendation.** Reset the quoted delivery windows on First Class and Second
Class to match observed performance — First Class as a two-day service, Second
Class as a four-day service. This converts most late deliveries into on-time ones
with no operational change, and it stops setting customer expectations the
business cannot meet. Longer term, if next-day First Class is a commercial
requirement, the fix belongs in fulfilment capacity, not in the promise.

## Finding 2 — Half the order book has never settled

Of $36.8M in order value, only $16.1M has reached a settled state (complete or
closed). $19.1M sits in the pipeline — pending, pending payment, processing, on
hold, or in payment review — and $8.1M of that is in pending payment alone. Only
about 4% of value is genuinely lost to cancellation or fraud.

This is a working capital issue, and it is larger in dollar terms than the
delivery problem. Money that is booked but never collected is money the business
cannot use.

**Recommendation.** Treat order settlement as a tracked metric with an owner.
Start with the $8.1M in pending payment, since that is the single largest stuck
state and the one most likely to have a fixable cause (payment capture, dunning,
or a checkout step that quietly fails). Introduce an aging view so leadership can
see how long value sits before it settles.

## Finding 3 — Fraud flags map to one payment method only

Every order flagged as suspected fraud in three years used a bank transfer.
Debit, cash, and other payment types show a fraud rate of exactly zero. Cancelled
orders show the same pattern. A result this clean, with no leakage across payment
types, is very unlikely to reflect real customer behaviour.

**Recommendation.** Do not treat the 2.26% fraud rate as an observed fraud
measure. It almost certainly reflects an automated review rule that flags
transfer orders. Confirm with the team that owns the order-management system what
sets these statuses before anyone uses this number for risk reporting. If it is a
rule, the useful question is whether it is too aggressive, since it is holding
real revenue in review.

## Caveats and scope

- **Data window.** Order volume drops by more than half from October 2017
  onward with no change in any other metric, which indicates incomplete data
  capture rather than a real decline. Analysis is therefore limited to January
  2015 through September 2017.
- **Uniformity.** Late delivery, margin, and discount rate were tested across
  market, customer segment, category, and day of week. They are flat on every
  dimension. This is why the analysis focuses on shipping mode and order status,
  where the real variation lives, rather than on geography or product.
- **Fraud.** As above, the fraud figure is treated as a system artifact, not an
  observed rate, pending confirmation from the business.

## What I would do next

- Build an order-status aging analysis to measure how long value sits in each
  pipeline state before settling.
- Confirm the fraud-flag logic with the order-management system owner.
- Speak with whoever owns the fulfilment SLAs to understand why the quoted
  windows were set where they are, before recommending the change in Finding 1.
- With line-level cost data, investigate why roughly one in five order lines
  loses money even at zero discount, which the current data cannot explain.
