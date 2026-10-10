# Take-Home Test: Uber Air Analytics Engineering

*Reconstructed employer brief. It restates the assignment as given to the candidate and contains no
implementation or workflow instructions.*

## Business context

Uber has hypothetically launched **Uber Air**, a marketplace matching aeroplane operators with individuals
and groups needing transport. The service wants to understand its regional growth drivers, the customer
segments it serves well, and its use cases — distance, geography, price tier, group/seat size, and aircraft
type — alongside portfolio-comparable metrics including daily, weekly, and monthly active users and revenue.
The business aims to facilitate 20% of global aeroplane rides by 2030.

## The ask

Design and implement a **reliable, scalable, maintainable, user-friendly analytical data model** for
monitoring and self-service analysis, based on the supplied operational datasets.

The model should support analysis of:

- **Regional growth** — supply and demand trends by geography.
- **Customer segments and groups** — who the service serves, and how well.
- **Use cases** — distance, geography, price tier, group/seat size, and aircraft type.
- **Active users** — daily, weekly, and monthly active users (DAU/WAU/MAU), with active-user semantics
  defined explicitly.
- **Revenue**, with revenue semantics defined explicitly.

## Deliverable

1. The **implemented analytical model** over the supplied datasets.
2. **Documentation explaining the design**: an ERD, a model dictionary with grains and keys, KPI
   definitions, assumptions, limitations and rationale — including metrics that cannot be computed reliably
   from the supplied data.

## Source data archive

The original supplied aircraft-model specification is archived unchanged at
[`docs/aeroplane_model.json`](aeroplane_model.json); the implementation-ready CSV converted from it lives at
[`data/aeroplane_model.csv`](../data/aeroplane_model.csv), with the conversion's fidelity evidence in
[`data/README.md`](../data/README.md).
