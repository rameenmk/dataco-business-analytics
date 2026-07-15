# Phase 2 - Analysis and Findings

Six business questions, answered with SQL against the star schema. Every number
below comes from a query in `sql/analysis.sql`.

## The headline

More than half of all shipments arrive late, the problem has not improved in
three years, and it is driven almost entirely by one thing: the company promises
delivery times on its fast shipping tiers that it cannot meet.

## Q1. How reliable is delivery?

About 55% of shipments are late. I checked three separate signals and they agree:
the late-delivery flag (54.8%), the actual delivery status marked "Late delivery"
(54.8%), and a direct comparison of real shipping days against promised days
(57.3%). When three independent measures land in the same place, the number is
trustworthy.

## Q2. What is driving it? (the root cause)

Breaking late rate down by shipping mode is where the real answer shows up:

| Shipping mode | Promised days | Actual days | Late % |
|---|---|---|---|
| First Class | 1 | 2 | 95.3 |
| Second Class | 2 | 4 | 76.6 |
| Same Day | 0 | 0.5 | 45.7 |
| Standard Class | 4 | 4 | 38.1 |

The pattern is clear. The faster the promised service, the worse the reliability.
First Class promises next-day and misses that promise 95% of the time, because it
actually takes two days on average. Standard Class, which pads its estimate to four
days, is the most reliable tier. The problem is not the warehouse being slow. The
problem is that the delivery-time promises on the premium tiers are set too
aggressively to ever be met.

## Q3. Is it getting better?

No. The monthly late rate sits around 55% from 2015 through 2017 and never trends
down. A problem this size that stays flat for three years usually means no one owns
it as a tracked metric.

## Q4. How much money is exposed?

Late deliveries touch roughly $20.1M of the $36.8M in total sales. The Consumer
segment carries the most, with about $10.5M of its sales sitting on late orders.
The late rate is basically the same across all three segments (around 55%), which
confirms this is a company-wide shipping issue, not a segment-specific one.

## Q5. Is the business profitable, and where are the losses?

The business is healthy overall: $3.97M profit on $36.8M sales, a net margin of
10.8%. But about 18.7% of order lines lose money.

I expected those losses to sit in a handful of bad products. They do not. Only 3 of
118 products lose money in total. The losses are spread thin across many lines
instead of being concentrated. That matters, because it means the fix is not
"drop a few products." It points at pricing and cost issues on individual lines.

## Q6. Does discounting hurt profit?

Yes, steadily. Average profit per line falls as the discount rises:

| Discount band | Avg profit per line | Lines at loss % |
|---|---|---|
| 0% | $26.67 | 18.4 |
| 1-10% | $23.39 | 18.6 |
| 11-20% | $20.71 | 18.8 |
| 21-25% | $18.41 | 19.0 |

Notice the loss rate stays near 18-19% even at 0% discount. So discounts erode the
average profit, but roughly one in five lines loses money regardless of discount.
That points to underlying cost or return problems, not just heavy discounting.

## What to actually do

1. Fix the delivery promises on First Class and Second Class. Either extend the
   quoted window to match reality (First Class is really a two-day service) or fix
   the fulfilment process on those lanes. This is the single highest-impact change,
   and it would move the headline late rate more than anything else.
2. Make on-time delivery a tracked KPI with a target and an owner. Three flat years
   suggest it currently is not.
3. Ask finance to look at the ~1 in 5 order lines that lose money even without a
   discount. That is a cost or returns question, not a pricing one.
4. Tighten approvals on discounts above 20%. They lower per-line profit without any
   sign in this data of a volume payoff.

## What feeds Phase 3

The shipping-mode reliability table is the hero chart for the dashboard. The
revenue-at-risk figure and the margin numbers become the top-line KPI cards.
