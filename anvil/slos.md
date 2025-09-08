# Service Level Objectives (SLOs) for Project Anvil

This document defines the reliability targets for the Project Anvil web service. These SLOs provide a shared understanding of our reliability goals and form the basis for our error budgets.

## 1. Key Services & User Journeys

- **Web Service:** The primary, user-facing website served through CloudFront.
- **Critical User Journey:** A user successfully loading the homepage.

---

## 2. Service Level Indicators (SLIs)

SLIs are the metrics we use to measure the performance of our service.

| SLI Name | Metric | Description |
| :--- | :--- | :--- |
| **Availability** | `(Success Requests / Total Requests) * 100` | The percentage of successful (HTTP 2xx, 3xx, 4xx) responses from the `web_tier` load balancer. 5xx errors count against this metric. |
| **Latency** | `p95 TargetResponseTime` | The 95th percentile latency of requests, measured at the `web_tier` load balancer. This means 95% of users experience this latency or better. |

---

## 3. Service Level Objectives (SLOs) & Error Budgets

SLOs are our specific reliability targets over a rolling 30-day window.

| SLI | SLO Target | Error Budget (30-day window) |
| :--- | :--- | :--- |
| **Availability** | **99.9%** | We can have **~43 minutes** of downtime per month. |
| **Latency** | **95%** of requests < **500ms** | **5%** of requests can be slower than 500ms. |

### SLO Alarms

- **Latency SLO Alarm:** A CloudWatch alarm (`web_slo_latency_burn`) will be created to monitor the p95 latency. This alarm will be less sensitive than the immediate `web_latency_warning` and is intended to alert the team when we are at risk of violating our monthly SLO.
